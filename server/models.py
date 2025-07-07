from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models
import os
from django.utils import timezone
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
import requests
import logging
from django.core.exceptions import ValidationError
import re

logger = logging.getLogger(__name__)

# 커스텀 사용자 관리
class CustomUserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('The Email field must be set')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)

        return self.create_user(email, password, **extra_fields)


# 커스텀 사용자 포멧
class CustomUser(AbstractBaseUser, PermissionsMixin):
    email = models.EmailField(unique=True)
    is_active = models.BooleanField(default=False)
    is_staff = models.BooleanField(default=False)
    login_attempts = models.IntegerField(default=0)  # 로그인 시도 횟수
    last_login_attempt = models.DateTimeField(null=True, blank=True)  # 마지막 로그인 시도 시간

    objects = CustomUserManager()  # 사용자 관리자를 설정합니다.

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = []

    def __str__(self):
        return self.email

#차량 모델. 차량 번호와 카메라 ip가 존재함
class Car(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)  # 외래키 설정
    camera_ip = models.GenericIPAddressField(unique=True, null=True)
    car_number = models.CharField(max_length=10)
    camera_serial = models.CharField(max_length=16, unique=True)
    is_active = models.BooleanField(default=False)
    
    def __str__(self):
        return self.car_number
    
    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['user', 'car_number'], name='unique_car_number_per_user')
        ]
    
    def delete(self, using=None, keep_parents=False):
        # 차량에 연결된 드라이버들 가져오기
        drivers = Driver.objects.filter(car=self)
        
        for driver in drivers:
            # 드라이버의 프로필 이미지 파일 경로
            profile_image_path = driver.profile_image.path  # 프로필 이미지의 경로 가져오기
            driver.delete()

            # 프로필 이미지 파일 삭제 (파일이 존재하는 경우에만)
            if os.path.exists(profile_image_path):
                os.remove(profile_image_path)  # 파일 삭제

        # FCM 토큰과 앱 IP를 차량 삭제 요청으로 보내기
        self.send_deletion_notification()

        # 차량 삭제
        super().delete(using, keep_parents)

    def send_deletion_notification(self):
        device = UserDevice.objects.filter(user=self.user).first()

        if device:
            print(f'{self.camera_ip} = 카메라 정보가 삭제되었습니다.')

            try:
                # 카메라에 정보 삭제 요청만 보냄
                requests.post(f"http://{self.camera_ip}:9999/clear_info", json={})
            except Exception as e:
                print(f"Failed to send deletion notification: {e}")


                
# 차량 추가 시 카메라에 FCM 토큰과 앱 IP 전송
@receiver(post_save, sender=Car)
def notify_on_car_add(sender, instance, created, **kwargs):
    device = UserDevice.objects.filter(user=instance.user).first()

    if device:
        fcm_token = device.fcm_token
        app_ip = device.app_ip
        print(f'{instance.camera_ip} 유저가 등록되었습니다.')           
        # 카메라 서버에 유저 정보가 등록됨
        try:
            requests.post(f"http://{instance.camera_ip}:9999/post_user", json={
                "fcm_token": fcm_token,
                "app_ip": app_ip,
            })
        except Exception as e:
            print(f"Failed to send addition notification: {e}")
                

class UserDevice(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    fcm_token = models.TextField()
    app_ip = models.GenericIPAddressField()

    def save(self, *args, **kwargs):
        if self.pk: 
            original = UserDevice.objects.get(pk=self.pk)
            # 값이 변경되었는지 확인
            if (original.fcm_token != self.fcm_token) or (original.app_ip != self.app_ip):
                print(f"유저 정보가 변경되었습니다.\n {original.app_ip} -> {self.app_ip}")

                try:
                    car = self.user.car_set.first()
                    if car:
                        requests.post(f"http://{car.camera_ip}:9999/post_user", json={
                            "fcm_token": self.fcm_token,
                            "app_ip": self.app_ip,
                        })
                except Exception as e:
                    print(f"Failed to send addition notification: {e}")
        
        super().save(*args, **kwargs)
        
    def __str__(self):
        return f'{self.user.email} - {self.app_ip}'

            


# 카메라 ip 및 비밀번호 모델
class Camera(models.Model):
    camera_ip =  models.GenericIPAddressField(unique=True, null=True)
    password = models.CharField(max_length=128)  # 해시된 비밀번호 저장
    camera_serial = models.CharField(max_length=16, unique=True)  # 시리얼 번호 추가

    def clean(self):
        # 시리얼 번호가 알파벳과 숫자만 포함되도록 유효성 검사
        if not re.match(r'^[A-Za-z0-9]+$', self.camera_serial):
            raise ValidationError('Serial number must contain only alphanumeric characters.')

    def save(self, *args, **kwargs):
        self.clean()  # save 호출 전에 유효성 검사
        super().save(*args, **kwargs)


# 차량에 등록된 운전자 명 + 운전자 + 차 번호
class Driver(models.Model):
    car = models.ForeignKey(Car, on_delete=models.CASCADE)  # 외래키로 차량 정보 연결
    drivername = models.CharField(max_length=50)  

    registration_date = models.DateTimeField(auto_now_add=True)  # 등록 날짜 자동 추가
    profile_image = models.ImageField(upload_to='profiles/')  # 프로필 이미지 서버에 저장

    def __str__(self):
        return self.drivername

    
    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['car', 'drivername'], name='unique_car_per_drivername')
        ]
    
# 운전자 추가 or 변경될 시 카메라로 전송 (변경은 구현 안할듯)
@receiver(post_save, sender=Driver)
def upload_profile_image(sender, instance, **kwargs):
    camera_ip = instance.car.camera_ip
    profile_image_path = instance.profile_image.path        
    # 카메라에 프로필 이미지 업로드 로직 추가
    url = f"http://{camera_ip}:9999/add_driver"  
    print(f"{camera_ip}운전자 이미지를 저장합니다. {instance.drivername}\n ")
   
    with open(profile_image_path, 'rb') as image_file:
        files = {'profile_image': image_file}
        try:
            requests.post(url, files=files)
        except Exception as e:
            print(f"Failed to send addition notification: {e}")
        

@receiver(post_delete, sender=Driver)
def delete_profile_image(sender, instance, **kwargs):
    # 드라이버가 삭제될 때 카메라에서 프로필 이미지 삭제
    camera_ip = instance.car.camera_ip
    profile_image_path = instance.profile_image.path  # 프로필 이미지의 경로 가져오기
    image_name = profile_image_path.split('/')[-1]  
    
    # 카메라 서버로 이미지 삭제 요청 
    url = f"http://{camera_ip}:9999/delete_driver"
    print(f"카메라 {camera_ip} 로 {instance.drivername} 드라이버의 \n{image_name} 이미지를 삭제합니다.")
    
    try:
        # JSON 데이터로 이미지 이름 보내기
        requests.post(url, json={"image_name": image_name})
    except Exception as e:
        print(f"Failed to send delete notification: {e}")
        





