import os
import urllib.request

def download_models(target_dir=None):
    if target_dir is None:
        target_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")
    os.makedirs(target_dir, exist_ok=True)
    base_dir = target_dir
    
    detector_url = "https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx"
    recognizer_url = "https://github.com/opencv/opencv_zoo/raw/main/models/face_recognition_sface/face_recognition_sface_2021dec.onnx"
    
    print("Downloading YuNet Face Detector model...")
    urllib.request.urlretrieve(detector_url, os.path.join(base_dir, "face_detection_yunet_2023mar.onnx"))
    
    print("Downloading SFace Recognizer model...")
    urllib.request.urlretrieve(recognizer_url, os.path.join(base_dir, "face_recognition_sface_2021dec.onnx"))
    
    print("Models downloaded successfully!")

if __name__ == "__main__":
    download_models()
