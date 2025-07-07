import cv2
import pickle
import threading
import numpy

import argparse

from datetime import datetime
from flask import Flask, render_template, Response, request,  jsonify
from picamera2 import Picamera2


from utils.db import *
from utils.hasher import Hasher
# fcm 토큰 setter, getter 추가됨
from utils.son_fcm import set_fcm_token, send_fcm, get_fcm_token
from face.face_model import Model
from face.drowsy_driving import calculate_EAR, counter, detect_eyes
from templates.log_html import generate_html_table

# ----------------son------------------
# 서버에 ip post
from utils.son_utils import send_camera_info, send_shutdown_signal, delete_images, delete_vectors
import atexit
# ip 허용 데코레이터
from functools import wraps
# 소리
import pygame
import time

parser = argparse.ArgumentParser()
parser.add_argument('--ip')
args = parser.parse_args()
camera_ip = args.ip

# 허용할 IP 리스트
allow_ips = ['34.64.207.115'] 



# 서버 및 카메라 세팅
app = Flask(__name__)
camera = Picamera2()
camera.start()
frame = None

driver_embeddings = []

lock = threading.Lock()

conn = dbconnect()  # db 연결

# 얼굴 인식 모델 관련 변수 선언
detector = 'dlib'
# recognizer = 'Dlib'
recognizer = 'ArcFace'
model = Model(detector=detector, recognizer=recognizer)

with open(file='face/user_vector.pickle', mode='rb') as f:
	user_vector = pickle.load(f)


# 졸음운전 탐지 관련 변수 선언
lastsave = 0
 
# 서버에 카메라 ip 호스트 및 활성화 알림 and fcm_token 및 app_ip 받아옴
fcm_token, app_ip = send_camera_info(camera_ip)
if fcm_token:
	set_fcm_token(fcm_token)
if app_ip:
	allow_ips.append(app_ip)
print(allow_ips)
print(f'\n{fcm_token=}\n{app_ip=}\n')

@counter
def close():
	 print('driver is drowsy')

# 알림 재생
def play_alarm():
    pygame.mixer.init()
    pygame.mixer.music.load('alarm.mp3')
    pygame.mixer.music.play()

    # 재생이 끝날 때까지 대기
    while pygame.mixer.music.get_busy():
        time.sleep(0.1)

def video_template(width=500, height=500):
	while True:
		array = camera.capture_array("main")
		#resized_arr = cv2.resize(array, (width, height))
		rgb_arr = cv2.cvtColor(array, cv2.COLOR_BGR2RGB)

		ret, frame = cv2.imencode('.jpg', rgb_arr)
		frame = frame.tobytes()
		yield (b'--frame\r\n'

			   b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')


def generate_driver_embeddings():
	global driver_embeddings
	driver_embeddings = []
	vector_dir = os.path.join(os.getcwd(), 'camera', 'driver_vectors')

    # 모든 pickle 파일을 읽어서 임베딩 리스트에 추가
	for filename in os.listdir(vector_dir):
		if filename.endswith('.pkl'):
			file_path = os.path.join(vector_dir, filename)
			with open(file_path, 'rb') as vector_file:
				embedding = pickle.load(vector_file)
				driver_embeddings.append(embedding)
	
	print(f"num of authorized driver: {len(driver_embeddings)}")


# 백그라운드 스레드에서 카메라로부터 프레임을 읽어오는 함수
def capture_frames():
	global camera, frame

	pre_face = False
	i = 0

	generate_driver_embeddings()

	while True:
		i += 1
		new_frame = camera.capture_array("main")  # 프레임 읽기
		new_frame = cv2.cvtColor(new_frame, cv2.COLOR_BGR2RGB)
		
		# print(f'얼굴 {i}: {pre_face}')

		with lock:
				frame = new_frame

		try:
			face, landmark = model.detect(new_frame)

		except:
			print("얼굴 미탐")
			pre_face = False
			continue

		else:
			# 얼굴이 탐지되지 않던 상황일 시 인식 수행
			if not pre_face:
				driver_vector = model.represent(face)
				result = None
				# 임베딩 벡터들과 비교
				for stored_vector in driver_embeddings:
					result = model.verify(driver_vector, stored_vector)  # 현재와 저장된 임베딩 비교
					print(result)
					if result:
						print("운전자가 인식되었습니다.")
						break
				pre_face = True
                
				print(f'인식 결과: {result}')
				info = 1

				if not result:
					info = 0
					result = send_fcm(title="운전자 인식 실패",
			  				 		  body="운전자를 확인하세요.")
					print(result)

				# db에 로그 기록
				now = datetime.now()
				time = now.strftime('%Y/%m/%d %H-%M-%S')

				path = f"/home/goose/capstone/log/{now.strftime('%Y_%m_%d_%H_%M_%S')}.png"
				# path = f"/home/goose/log/{i}.png"
				# info = 1 if result else 0
				log_insert(conn, info, path, time)
				cv2.imwrite(path, new_frame)

			# 이미 얼굴이 탐지되던 상황이면 졸음운전 탐지 수행			
			else:
				left_eye, right_eye = detect_eyes(landmark)
				left_EAR = calculate_EAR(left_eye)
				right_EAR = calculate_EAR(right_eye)
				EAR = (left_EAR + right_EAR) / 2
				EAR = round(EAR, 2)

				if EAR < 0.20:
					close()
					print(f'close count: {close.count}', end='\n\n')

					# 이부분 음성으로 처리하게 바꾸기만 하면 될듯 합니당
					if close.count == 0:
						# 경고음 재생
						play_alarm()
						send_fcm(title="졸음운전 감지",
			  					 body="정신차리세요.")
						print("Driver is sleeping!!!!!!!!!!!!!!!!!!!\n 비프음 발생! 스피커 총동원! 삐삐삐삐------")
						info = 2
						log_insert(conn, info, path, time)


		# finally:
		#	 with lock:
		#		 frame = new_frame

# 백그라운드 스레드 시작
thread = threading.Thread(target=capture_frames)

thread.daemon = True
thread.start()

'''--------------------- by son start-----------------------'''
# ip 허용 데코레이터 정의
def require_ip(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        client_ip = request.remote_addr  # 요청한 클라이언트 IP
        if client_ip not in allow_ips:
            return jsonify({'error': 'Access Deny.'}), 403  # 접근 거부
        return f(*args, **kwargs)
    return decorated_function

# 사용자가 운전자 사진, fcm 토큰, ip, 벡터 등록된거 삭제함
@app.route('/clear_info', methods=['POST'])
#@require_ip
def clear_info():
	global allow_ips
	print("\napp_ip, driver images, fcm_toekn 다 지울거임!\n")
	delete_images()
	set_fcm_token(None)
	allow_ips = ['34.64.207.115']
	delete_vectors()
 
	return "Success"

# 사용자 앱에서 fcm 이나 ip가 처음 등록 or 변경 시, fcm과 ip 변경
@app.route('/post_user', methods=['POST'])
#@require_ip
def post_user():
	global allow_ips
	data = request.get_json()
	print('\n fcm token 과 app ip 를 받음\n')
	print(f"{data}\n")
	# fcm_token 값을 업데이트 (set_fcm_token을 통해)
	fcm_token = data.get('fcm_token')
	app_ip = data.get('app_ip')
	if fcm_token:
		set_fcm_token(fcm_token)  # utils/son_fcm.py의 setter 함수 호출

	if app_ip:
		print("ip 바뀜")
		#allow_ips = ['34.64.207.115']
		allow_ips = ['10.147.20.187']
		allow_ips.append(app_ip)
 
	return "Success"

# 운전자 사진 및 임베딩 벡터 저장
@app.route('/add_driver', methods=['POST'])
#@require_ip
def add_driver():
	save_dir = os.path.join(os.getcwd(), 'camera', 'drivers')
	vector_dir = os.path.join(os.getcwd(), 'camera', 'driver_vectors')
	if not os.path.exists(save_dir):
		os.makedirs(save_dir)
	if not os.path.exists(vector_dir):
		os.makedirs(vector_dir)
        
	file = request.files['profile_image']
	if file.filename == '':
		return "No selected file", 400


    # 파일을 '/camera/drivers/' 경로에 저장
	file_path = os.path.join(save_dir, file.filename)
	#cv2.imwrite(file_path, img)
	file.save(file_path)
 
	# 얼굴 임베딩 계산
	img = cv2.imread(file_path)
	try:
		with lock:
			face, _ = model.detect(img)
	except:
		return "no face in image", 400
	face_embedding = model.represent(face)

    # 임베딩 벡터를 pickle 파일로 저장
	vector_file_path = os.path.join(vector_dir, f"{file.filename}.pkl")
	with open(vector_file_path, 'wb') as vector_file:
		pickle.dump(face_embedding, vector_file)

	generate_driver_embeddings()
        
	print(f"\n운전자 프로필 사진 '{file.filename}' 저장 완료: {file_path}\n")
    
	return "Success"
 
# 운전자 사진 삭제
@app.route('/delete_driver', methods=['POST'])
#@require_ip
def delete_driver():
    data = request.get_json()
    image_name = data.get('image_name')
    image_path = os.path.join(os.getcwd(), 'camera', 'drivers', image_name)
    vector_path = os.path.join(os.getcwd(), 'camera', 'driver_vectors', f"{image_name}.pkl")
    os.remove(image_path)
    os.remove(vector_path)
    print(f"\n운전자 프로필 사진 '{image_name}' 삭제 완료: {image_path}\n")
    return "Success"

'''--------------------- by son end-----------------------'''



# /video 라우터에 접근 시 프레임을 지속적으로 전송하는 라우터
@app.route('/video')
#@require_ip
def video_feed():
	def generate():
		global frame
		while True:
			# with lock:
			if frame is not None:
				cv2.imwrite('frame.png', frame)
				ret, buffer = cv2.imencode('.jpg', frame)  # 프레임을 JPEG 형식으로 인코딩
				frame_bytes = buffer.tobytes()
				yield (b'--frame\r\n'				
						b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')  # 이미지 데이터를 바이트 스트림으로 반환

	#return Response(generate(), mimetype='multipart/x-mixed-replace; boundary=frame')
	return Response(video_template(), mimetype='multipart/x-mixed-replace; boundary=frame')


@app.route('/token', methods=['POST'])
#@require_ip
def token():
	data = request.get_json()
	token = data.get('token')
	user_token_modify(conn, token)

	return "Success"


@app.route('/log2', methods=['GET'])
#@require_ip
def log2():
	log_list = fetch_all(conn, 'log')
	json_data = []

	for log in log_list:
		data = {}
		data['id'], data['info'], data['img'], data['time'] = log
		json_data.append(data)

	return generate_html_table(json_data)




# 홈페이지
@app.route('/')
#@require_ip
def index():
	return render_template('index.html')



if __name__ == '__main__':
	atexit.register(send_shutdown_signal) # 카메라 종료 시 서버에 deactive 보냄
    
	app.run(host='0.0.0.0', port=9999, threaded=True)

