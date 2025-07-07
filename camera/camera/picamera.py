import cv2
import time

from picamera2 import Picamera2


picam2 = Picamera2()
picam2.start()
time.sleep(1)

array = picam2.capture_array("main")

cv2.imshow("test", array)
cv2.waitKey(0)
cv2.destroyWindow("test")
