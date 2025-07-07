# accounts/views.py
from django.utils import timezone
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required

from dku_django import settings
from .forms import SignUpForm
from rest_framework.views import APIView, exception_handler
from rest_framework.response import Response
from rest_framework import status, viewsets, generics
from .serializers import CarSerializer, UserDeviceSerializer, UserRegistrationSerializer, DriverSerializer
from .models import Car, UserDevice, Driver, CustomUser, Camera
from django.http import JsonResponse, FileResponse, Http404
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.decorators import api_view, permission_classes
from rest_framework.exceptions import NotFound
import os 
import hashlib
from django.contrib.sites.shortcuts import get_current_site
from .tokens import account_activation_token 
import json
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth import get_user_model
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode

from django.utils.encoding import force_bytes, force_str
from django.template.loader import render_to_string
from django.core.mail import EmailMultiAlternatives
from django.contrib.auth import authenticate, login
from django.contrib.auth.forms import AuthenticationForm
from django.contrib.auth import logout
from django.contrib import messages
import requests

User = get_user_model()

def home(request):
    return render(request, 'home.html', {'user': request.user})

def logout_view(request):
    logout(request)  # 사용자를 로그아웃합니다.
    return redirect('home')

def login_view(request):
    if request.method == 'POST':
        form = AuthenticationForm(request, data=request.POST)
        if form.is_valid():
            username = form.cleaned_data.get('username')
            password = form.cleaned_data.get('password')
            user = authenticate(username=username, password=password)
            if user is not None:
                login(request, user)
                device = UserDevice.objects.filter(user_id=user.id).first()
                fcm_token = device.fcm_token
                # IP 주소 업데이트
                ip = request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR'))
                UserDevice.objects.update_or_create(
                    user=user,
                    defaults={'fcm_token': fcm_token, 'app_ip': ip}
                )
                
                
                # 토큰 정보를 JSON 응답으로 반환
                return redirect('web_car_list')
    else:
        form = AuthenticationForm()
    return render(request, 'registration/login.html', {'form': form})

@login_required  # 로그인이 되어 있어야 이 뷰에 접근 가능
def web_car_list(request):
    user = request.user  # 로그인한 사용자
    cars = Car.objects.filter(user_id=user.id)  # 로그인한 사용자가 등록한 차량만 필터링
    #device = UserDevice.objects.filter(user_id=user.id).first()
    #fcm_token = device.fcm_token
    #app_ip = device.app_ip
    for car in cars:
        camera_server_url = f'http://{car.camera_ip}:9999'  # 각 차량의 camera_ip 사용
        try:
            response = requests.get(camera_server_url, timeout=5)
            print(camera_server_url)
            print(response)
            is_camera_active = (response.status_code == 200)
        except requests.exceptions.RequestException:
            print(camera_server_url)
            print(response)
            is_camera_active = False
            
        # is_active 값 업데이트
        car.is_active = is_camera_active
        car.save(update_fields=['is_active'])
    return render(request, 'registration/cars.html', {'cars': cars})

@login_required
def web_add_car(request):
    print("Request Method:", request.method)
    print("Requested URL:", request.path)
    print("User:", request.user)
    if request.method == 'POST':
        car_number = request.POST.get('car_number')
        camera_serial = request.POST.get('camera_serial')
        camera_password = request.POST.get('camera_password')
        hashed_password = hashlib.sha256(camera_password.encode()).hexdigest()
        print("POST Data:", request.POST)
        # 카메라 시리얼 번호로 camera 비밀번호 찾기
        try:
            camera = Camera.objects.get(camera_serial=camera_serial)
        except Camera.DoesNotExist:
            messages.error(request, '존재하지 않는 카메라 시리얼 번호입니다.')
            return redirect('web_car_list')
        print(hashed_password)
        # 입력한 비밀번호가 해시된 비밀번호와 일치하는지 확인
        if hashed_password == camera.password:
            Car.objects.create(
                car_number=car_number,
                camera_serial=camera_serial,
                user_id=request.user.id,
                camera_ip=camera.camera_ip
            )
            messages.success(request, '차량 정보가 성공적으로 추가되었습니다.')
        else:
            messages.error(request, '카메라 비밀번호가 일치하지 않습니다.')

        return redirect('web_car_list')

    return render(request, 'registration/cars.html')

@login_required
def web_delete_car(request, camera_serial):
    if request.method == 'POST':
        try:
            car = Car.objects.get(camera_serial=camera_serial, user=request.user)
            car.delete()
            messages.success(request, '차량이 성공적으로 삭제되었습니다.')
        except Car.DoesNotExist:
            messages.error(request, '해당 차량을 찾을 수 없습니다.')

    return redirect('web_car_list')

@login_required
def web_main_view(request, camera_serial):
    car = Car.objects.get(camera_serial=camera_serial, user=request.user)
    baseUrl = car.camera_ip
    drivers = Driver.objects.filter(car=car)
    logUrl = f'http://{baseUrl}:9999/log2'
    streamingUrl = f'http://{baseUrl}:9999/'
    return render(request, 'registration/web_main_view.html', {
        'drivers': drivers,
        'logUrl': logUrl,
        'streamingUrl': streamingUrl,
        'camera_serial': car.camera_serial
    })

@login_required
def web_add_driver(request, camera_serial):
    if request.method == 'POST':
        car = Car.objects.filter(camera_serial=camera_serial).first()
        if not car:
            return Response({'detail': 'Car not found.'}, status=status.HTTP_404_NOT_FOUND)

        # request.FILES와 request.POST를 합쳐서 data에 전달
        data = request.POST.copy()  # POST 데이터 복사
        data.update(request.FILES)   # FILES 데이터 추가

        serializer = DriverSerializer(data=data)
        if serializer.is_valid():
            serializer.save(car=car, registration_date=timezone.now())
            messages.success(request, '운전자가 성공적으로 추가되었습니다.')
        else:
            print(serializer.errors) 
            messages.error(request, f'운전자 추가 중 오류가 발생했습니다 : {serializer.errors}')
        
        return redirect('web_main_view', camera_serial=camera_serial)

    return render(request, 'registration/web_main_view.html')



@login_required
def web_delete_driver(request, camera_serial, drivername):
    if request.method == 'POST':
        car = Car.objects.get(camera_serial=camera_serial)
        driver = Driver.objects.get(drivername=drivername, car=car)

        # 드라이버의 프로필 이미지 파일 경로
        profile_image_path = driver.profile_image.path  # 프로필 이미지의 경로 가져오기
        try:
            driver.delete()
            messages.success(request, '운전자가 성공적으로 삭제되었습니다.')
        except Driver.DoesNotExist:
            messages.error(request, '해당 운전자를 찾을 수 없습니다.')

        # 파일 삭제 (파일이 존재하는 경우에만)
        if os.path.exists(profile_image_path):
            os.remove(profile_image_path)  # 파일 삭제

        return redirect('web_main_view', camera_serial=camera_serial)

    return redirect('web_main_view', camera_serial=camera_serial)


@csrf_exempt
def receive_camera_ip(request):
    if request.method != 'POST':
        return JsonResponse({'status': 'error', 'message': 'Invalid request method.'}, status=405)  
    try:
        print(request.body)
        # JSON 데이터 파싱
        data = json.loads(request.body)
        camera_serial = data.get('camera_serial')
        camera_ip = data.get('camera_ip')
        print(data)
        print(f"Received serial number: {camera_serial}, camera IP: {camera_ip}")
    
        # 카메라 시리얼 번호로 카메라 객체 찾기
        camera = Camera.objects.filter(camera_serial=camera_serial).first()
        camera.camera_ip = camera_ip
        camera.save()
        if not camera:
            raise Car.DoesNotExist
        
        car = Car.objects.filter(camera_serial=camera_serial).first()
        if not camera:
            raise Camera.DoesNotExist
        
        car.camera_ip = camera_ip
        car.save()
        # 차량에 등록된 카메라에 저장된 fcm_token과 app_ip 전송
        car = Car.objects.filter(camera_serial=camera_serial).first()
        if car:
            user_device = UserDevice.objects.filter(user_id=car.user_id).first()
            if user_device:
                fcm_token = user_device.fcm_token
                app_ip = user_device.app_ip
                response_message = {'status': 'update', 'message': 'Camera IP updated successfully.', 'fcm_token' : fcm_token, 'app_ip' : app_ip}
            else :
                camera_info_cleared = f"{camera_ip} 카메라의 정보가 삭제되었습니다."
                response_message = {'status': 'clear_info', 'message': camera_info_cleared}
        else: 
            # 차량이 등록되어 있지 않으면 카메라 정보 삭제
            camera_info_cleared = f"{camera_ip} 카메라의 정보가 삭제되었습니다."
            response_message = {'status': 'clear_info', 'message': camera_info_cleared}
        
        #차량 상태를 활성화
        car.is_active = True
        car.save()
        status_code = 200

    except json.JSONDecodeError:
        response_message, status_code = {'status': 'error', 'message': 'Invalid JSON format.'}, 400
    except Camera.DoesNotExist:
        response_message, status_code = {'status': 'error', 'message': 'Camera does not exist.'}, 404
    except Exception as e:
        print('yeogi')
        response_message, status_code = {'status': 'error', 'message': f'Unexpected error: {str(e)}'}, 500

    return JsonResponse(response_message, status=status_code)

@csrf_exempt
def deactive_camera(request, camera_serial):
    if request.method == 'POST':
        # 카메라 종료 시, 상태를 비활성화로 변경
        print(f"Shutdown signal received for camera serial: {camera_serial}")
        car = Car.objects.filter(camera_serial=camera_serial).first() 
        car.is_active = False
        car.save()
        
        return JsonResponse({'status': 'success', 'message': 'Shutdown signal processed.'}, status=200)

    return JsonResponse({'status': 'error', 'message': 'Invalid request method.'}, status=405)

# 미디어 파일 전송..
@login_required
def serve_media_file(request, file_path):
    absolute_path = os.path.join(settings.MEDIA_ROOT, file_path)
    driver_id = file_path.split('/')[-1].split('.')[0]  
    
    try:
        driver = Driver.objects.get(profile_image__endswith=driver_id + '.jpg')  # 이미지 파일 이름으로 드라이버 찾기

        # 드라이버와 연결된 차량의 사용자 확인
        if driver.car.user != request.user:
            raise Http404("You do not have permission to access this file.")
    except Driver.DoesNotExist:
        raise Http404("File not found.")

    if os.path.exists(absolute_path):
        return FileResponse(open(absolute_path, 'rb'))
    raise Http404("File not found.")

def error_view(request, exception=None):
    return render(request, 'error.html',
                  {'status_code': exception.status_code if exception else 500},
                  status=exception.status_code if exception else 500)


def home(request):
    return render(request, 'home.html')  # 기본 뷰


def signup(request):
    if request.method == 'POST':
        form = SignUpForm(request.POST)
        if form.is_valid():
            user = form.save(commit=False)  # 사용자 객체 생성
            user.set_password(form.cleaned_data['password1'])  # 비밀번호 해시화
            user.save()  # 사용자 객체 저장
            
            current_site = get_current_site(request)
            mail_subject = 'Activate your account.'
            message = render_to_string('accounts/account_activation_email.html', {
                'user': user,
                'domain': current_site.domain,
                'uid': urlsafe_base64_encode(force_bytes(user.pk)),
                'token': account_activation_token.make_token(user),
            })
            email = EmailMultiAlternatives(mail_subject, message, to=[user.email])
            email.attach_alternative(message, "text/html")  # HTML로 콘텐츠 추가
            email.send()

            return render(request, 'accounts/registration_done.html') 
    else:
        form = SignUpForm()
    return render(request, 'accounts/signup.html', {'form': form})

# 인증 이메일 활성화 뷰
def activate(request, uidb64, token):
    try:
        uid = force_str(urlsafe_base64_decode(uidb64))
        user = User.objects.get(pk=uid)
    except (TypeError, ValueError, OverflowError, User.DoesNotExist):
        user = None

    if user is not None and account_activation_token.check_token(user, token):
        user.is_active = True
        user.save()
        login(request, user)
        return render(request, 'accounts/registration_complete.html', {'user': user})
    else:
        return render(request, 'accounts/activation_invalid.html')

"""여기서 부터는 api(어플) 관련 뷰 입니다"""



# api view! - signup user
class UserRegistrationView(APIView):
    permission_classes = [AllowAny]
    def post(self, request):
        serializer = UserRegistrationSerializer(data=request.data)

        if serializer.is_valid():
            user = serializer.save()  # 사용자 저장

            # 이메일 전송 로직
            current_site = get_current_site(request)
            mail_subject = 'Activate your account.'
            message = render_to_string('accounts/account_activation_email.html', {
                'user': user,
                'domain': current_site.domain,
                'uid': urlsafe_base64_encode(force_bytes(user.pk)),
                'token': account_activation_token.make_token(user),
            })
            email = EmailMultiAlternatives(mail_subject, message, to=[user.email])
            email.attach_alternative(message, "text/html")
            email.send()
            return Response({'message': 'User registered successfully!'}, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# api view! - return cars info
@permission_classes([IsAuthenticated])
class CarViewSet(viewsets.ModelViewSet):
    queryset = Car.objects.all()
    serializer_class = CarSerializer
    
    def get_queryset(self):
        cars = self.queryset.filter(user=self.request.user)
        
        # 각 차량의 카메라 서버 상태 체크 및 fcm, app ip 업데이트
        for car in cars:
            camera_server_url = f'http://{car.camera_ip}:9999'  # 각 차량의 camera_ip 사용    
            print(f'{camera_server_url} 업데이트 되었습니다.')
            try:
                response = requests.get(camera_server_url, timeout=5)
                is_camera_active = (response.status_code == 200)
            except requests.exceptions.RequestException:
                is_camera_active = False
            
            # is_active 값 업데이트
            car.is_active = is_camera_active
            car.save(update_fields=['is_active'])

        return cars
    def get_is_active(self, request, *args, **kwargs):
        # 현재 사용자의 차량 정보 중 is_active만 포함한 리스트 생성
        cars = self.get_queryset()
        car_statuses = [{'car_number': car.car_number, 'is_active': car.is_active} for car in cars]
        
        return Response(car_statuses)
    
    
# api view! - app info
class UserDeviceViewSet(viewsets.ModelViewSet):
    queryset = UserDevice.objects.all()
    serializer_class = UserDeviceSerializer
    def create(self, request, *args, **kwargs):
        user_device = UserDevice.objects.create(
            user=request.user,
            fcm_token=request.data.get('fcm_token'),
            app_ip=request.data.get('app_ip')
        )
        serializer = self.get_serializer(user_device)
        return Response(serializer.data)

# api view! - car regist
@api_view(['POST'])
@permission_classes([IsAuthenticated])  # 인증된 사용자만 접근 가능
def add_car(request):
    serializer = CarSerializer(data=request.data)
    if serializer.is_valid():
        camera_serial = serializer.validated_data['camera_serial']  # serializer에서 camera_serial 가져오기
        camera = Camera.objects.filter(camera_serial=camera_serial).first()  # 카메라 정보 가져오기
        
        if not camera:
            return Response({"error": "Please Check your serial number and password of the camera."}, status=status.HTTP_404_NOT_FOUND)

        # 비밀번호 확인
        password = request.data.get('password')  # 요청에서 비밀번호 가져오기
        hashed_password = hashlib.sha256(password.encode()).hexdigest()  # 비밀번호 해시화
        
        if camera.password != hashed_password:
            return Response({"error": "Please Check the serial number and password of the camera."}, status=status.HTTP_400_BAD_REQUEST)

        # 차량 등록
        car_instance = serializer.save(user=request.user)  # 차량 등록 시 사용자 정보 추가
        
        # 카메라 IP를 차량 IP에 설정
        car_instance.camera_ip = camera.camera_ip
        car_instance.save()  # 변경 사항 저장
        
        
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    return Response({"error": "Failed to add car or camera.", "details": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

# api view! - car delete
@api_view(['DELETE'])
@permission_classes([IsAuthenticated])  # 인증된 사용자만 접근 가능
def delete_car(request, camera_serial):
    try:
        car = Car.objects.get(camera_serial=camera_serial, user=request.user)  # 차량 찾기
        camera_serial = car.camera_serial
        car.delete()  # 차량 삭제
        
        
        return Response(status=status.HTTP_204_NO_CONTENT)  # 성공적인 삭제 응답
    except Car.DoesNotExist:
        return Response({'error': 'Car not found.'}, status=status.HTTP_404_NOT_FOUND)  # 차량이 존재하지 않을 때
    
    
# api view! - login
class LoginView(APIView):
    permission_classes = [AllowAny]
    
    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')
        user = CustomUser.objects.filter(email=email).first()
        
        if user is not None:
            # 로그인 시도 횟수 및 시간 체크
            if user.login_attempts >= 5:
                if timezone.now() - user.last_login_attempt < timezone.timedelta(minutes=15):  # 15분 동안 차단
                    return JsonResponse({'message': 'Account is locked. Try again later.'}, status=403)
            
            # 비밀번호 확인
            if user.check_password(password):
                user.login_attempts = 0  # 로그인 성공 시, 시도 횟수 초기화
                user.save()
                
                login(request, user)
                
                ip = request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR'))
                
                
                # 사용자 디바이스 정보 저장
                UserDevice.objects.update_or_create(
                    user=user,
                    defaults={'fcm_token': request.data.get('fcm_token'), 'app_ip': ip}
                )           
                

                refresh = RefreshToken.for_user(user)
                access_token = str(refresh.access_token)
                
                # 차량 번호와 카메라 IP 가져오기
                user_cars = Car.objects.filter(user=user)
                car_numbers = [car.car_number for car in user_cars]  # 차량 번호 리스트
                camera_ips = [car.camera_ip for car in user_cars]  # 카메라 IP 리스트
                camera_serials = [car.camera_serial for car in user_cars]
                is_actives = [car.is_active for car in user_cars]
                 
                return JsonResponse({
                    'message': 'Login successful!',
                    'access': access_token,  # Access Token 응답에 포함
                    'refresh': str(refresh),  # Refresh Token 응답에 포함
                    'car_numbers': car_numbers,
                    'camera_ips': camera_ips,
                    'camera_serials' : camera_serials,
                    'is_actives' : is_actives,
                }, status=200)
            else:
                user.login_attempts += 1  # 로그인 실패 시, 시도 횟수 증가
                user.last_login_attempt = timezone.now()
                user.save()
                return JsonResponse({'message': 'Please check your email and password.'}, status=401)
        else:
            return JsonResponse({'message': 'Please check your email and password.'}, status=401)

@permission_classes([IsAuthenticated])
class DriverListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = DriverSerializer

    def get_queryset(self):
        camera_serial = self.kwargs['camera_serial']
        car = Car.objects.filter(camera_serial=camera_serial).first()
        if car:
            return Driver.objects.filter(car=car)  
        return Driver.objects.none()  # 차량이 없을 경우 빈 쿼리셋 반환

    def post(self, request, camera_serial):
        car = Car.objects.filter(camera_serial=camera_serial).first()
        if not car:
            return Response({'detail': 'Car not found.'}, status=status.HTTP_404_NOT_FOUND)

        serializer = DriverSerializer(data=request.data)
        
        if serializer.is_valid():
            serializer.save(car=car)  # 차량에 연결하여 드라이버 저장
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response({"error": "Test Message", "details": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

    
@permission_classes([IsAuthenticated])
class DriverDeleteAPIView(generics.DestroyAPIView):
    serializer_class = DriverSerializer
    def get_object(self):
        drivername = self.kwargs['drivername']
        camera_serial = self.kwargs.get('camera_serial')  # camera_serial를 URL에서 가져옴

        try:
            # camera_serial에 해당하는 차량을 찾음
            car = Car.objects.get(camera_serial=camera_serial)
            # 차량과 드라이버 이름으로 드라이버를 찾음
            return Driver.objects.get(drivername=drivername, car=car)
        except Car.DoesNotExist:
            raise NotFound("Can not found car with camera seiral.")
        except Driver.DoesNotExist:
            raise NotFound("There is no driver matching the name.")

    def destroy(self, request, *args, **kwargs):
        driver = self.get_object()
        
        # 드라이버의 프로필 이미지 파일 경로
        profile_image_path = driver.profile_image.path  # 프로필 이미지의 경로 가져오기
        
        # 드라이버 삭제
        self.perform_destroy(driver)
        
        # 파일 삭제 (파일이 존재하는 경우에만)
        if os.path.exists(profile_image_path):
            os.remove(profile_image_path)  # 파일 삭제
            
        return Response(status=status.HTTP_204_NO_CONTENT)
    
# api view! - 처리되지 않은 예외 처리기    
def custom_exception_handler(exc, context):
    response = exception_handler(exc, context)

    if response is None:  # 처리되지 않은 예외인 경우
        return Response({'error': 'An unexpected error occurred.'}, status=500)

    return response
