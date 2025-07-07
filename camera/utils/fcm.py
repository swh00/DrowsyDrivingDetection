import firebase_admin

from firebase_admin import credentials
from firebase_admin import messaging

# fcm_token을 전역 변수로 관리함
import threading
_fcm_token = None
lock = threading.Lock()

# getter 함수로 fcm_token을 반환
def get_fcm_token() -> str:
    global _fcm_token
    with lock:
        return _fcm_token

def set_fcm_token(token: str):
    global _fcm_token
    _fcm_token = token

# cred_path = 'auth.json'
cred_path = 'fcm_fuck.json'
cred = credentials.Certificate(cred_path)
firebase_admin.initialize_app(cred)


def send_fcm(title:str, body:str):
	token = get_fcm_token()  # fcm_token을 가져옴
	if not token:
		print("FCM Token is missing. Please provide a valid token.")
		return None
    
	message = messaging.Message(
		notification=messaging.Notification(
			title = title,
			body = body
		),
	
		token=token
	)
	try:
		response = messaging.send(message)
		return response
	except Exception as e:
		print(f"Error sending FCM: {e}")
		return None
	

if __name__ == "__main__":
	token = get_fcm_token()
	message = messaging.Message(
	notification=messaging.Notification(
		title='test',
		body='python push test'
	),

	token = token
)
	response = messaging.send(message)
	print(response)
