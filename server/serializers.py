"""
회원가입에 필요한데이터 직렬화
"""

from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Car, UserDevice, CustomUser, Driver, Camera
import base64
from rest_framework import serializers
import os
import uuid
import re


class CarSerializer(serializers.ModelSerializer):
    class Meta:
        model = Car
        fields = ['car_number', 'camera_serial', 'camera_ip', 'is_active']

    def validate_camera_serial(self, value):
        # camera_serial가 카메라에 존재하는지 확인
        if not Camera.objects.filter(camera_serial=value).exists():
            raise serializers.ValidationError("This camera serial number does not exist.")
        
        # camera_serial가 이미 등록된 차량의 경우 확인
        if Car.objects.filter(camera_serial=value).exists():
            raise serializers.ValidationError("This camera serial number is already in use by another car.")
        
        return value
#apple data
class UserDeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserDevice
        fields = ['fcm_token', 'app_ip']


#user data
class UserRegistrationSerializer(serializers.ModelSerializer):
    password1 = serializers.CharField(write_only=True)
    password2 = serializers.CharField(write_only=True)

    class Meta:
        model = CustomUser
        fields = ('email', 'password1', 'password2')

    def validate(self, data):
        password1 = data['password1']
        password2 = data['password2']

        if password1 != password2:
            raise serializers.ValidationError("The passwords do not match.")

        # 비밀번호 복잡성 검사
        if not self.is_valid_password(password1):
            raise serializers.ValidationError(
                "Password must be at least 8 characters long and contain uppercase, lowercase, digit, and special character."
            )
        return data


    #비밀번호 복잡성 추가
    def is_valid_password(self, password):
        return (len(password) >= 8 and
                re.search(r"[A-Z]", password) and   # 대문자
                re.search(r"[a-z]", password) and   # 소문자
                re.search(r"[0-9]", password) and   # 숫자
                re.search(r"[!@#$%^&*(),.?\":{}|<>]", password))  # 특수 문자
        
    def create(self, validated_data):
        user = CustomUser.objects.create_user(
            email=validated_data['email'],
            password=validated_data['password1']  # password1을 사용하여 사용자 생성
        )
        return user
    
#image data for driver data
class ImageFieldWithFile(serializers.ImageField):
    def to_representation(self, value):
        if value:
            with open(value.path, 'rb') as image_file:
                image_content = image_file.read()
            # Base64 인코딩
            encoded_image = base64.b64encode(image_content).decode('utf-8')
            return f"data:image/jpeg;base64,{encoded_image}"  # MIME 타입을 맞춰서 반환
        return None


#driver data
class DriverSerializer(serializers.ModelSerializer):
    profile_image = ImageFieldWithFile()
    class Meta:
        model = Driver
        fields = ['drivername', 'registration_date', 'profile_image']
    
    def create(self, validated_data):
        if 'profile_image' in validated_data:
            profile_image = validated_data['profile_image']
            drivername = validated_data['drivername']
            upload_dir = f"driver_images/{drivername}/"  # 드라이버 이름으로 디렉토리 생성
            
            # 고유한 파일 이름 생성
            file_extension = os.path.splitext(profile_image.name)[1]
            unique_filename = f"{uuid.uuid4()}{file_extension}"
            
            validated_data['profile_image'].name = os.path.join(upload_dir, unique_filename)

        return super().create(validated_data)

