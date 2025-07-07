import base64
import pymysql
import os

from utils.hasher import Hasher

def dbconnect():
	conn = pymysql.connect(host='127.0.0.1', user='user', password='pw', db='db', charset='utf8')
	return conn


def user_token_modify(conn, token):
	cur = conn.cursor()
	# sql = f"UPDATE user SET token = {token} WHERE id = 1;"
	sql = 'UPDATE user SET token = %s WHERE id = 1'
	cur.execute(sql, (token))
	conn.commit()

def log_insert(conn, info, img, time):
	cur = conn.cursor()
	cur.execute('''INSERT INTO log (info, img, time) VALUES (%s, "%s", "%s");'''%(info, img, time))
	conn.commit()

 
def fetch_all(conn, table, limit=20):
	cur = conn.cursor()
	sql = f"SELECT * FROM {table} ORDER BY id DESC LIMIT {limit}"
	cur.execute(sql)
	results = cur.fetchall()
	return results


def get_img_bytes(img_path): # 이미지주소 입력받고 바이트배열로 반환하는 함수
	img_bytes = open(img_path, 'rb').read()
	encoded_string = base64.b64encode(img_bytes)

	return encoded_string.decode()  # 전송할 때 문자열로 변환(bytes면 오류남)


def signup(conn, user_id, user_password, token):
	hasher = Hasher([user_password])
	hashed_password = hasher.generate(user_password)
	cur = conn.cursor()
	cur.execute('''INSERT INTO user (user_id, user_pw, token) VALUES (%s, "%s", "%s");'''%(user_id, hashed_password, token))
	conn.commit()


#def get_user_info
