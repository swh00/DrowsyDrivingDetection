import cv2
import time

from picamera2 import Picamera2

def capture(picam=None, width=500, height=500):
	while True:
		image = picam.capture_array("main")
		image = cv2.resize(image, (width, height))
		image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

		# ret, frame = cv2.imencode('.jpg', rgb_arr)
		# frame = frame.tobytes()
		yield image

	picam2.stop()

if __name__=="__main__":
	picam2 = Picamera2()
	picam2.start()

	for frame in capture(picam2):
		cv2.imshow("test1",frame)
		key = cv2.waitKey(1)
		if key == ord('q'): # 'q'누르면 종료
			cv2.imwrite("your_face_before.png",frame)
			time.sleep(1)
			cv2.imwrite("your_face_after.png", frame)
			break

	cv2.destroyAllWindows()
