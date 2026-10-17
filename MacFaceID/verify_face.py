import sys
import os
import cv2
import numpy as np
import time
from datetime import datetime

LOG_FILE = "/tmp/macfaceid.log"

def log(msg):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    entry = f"[{timestamp}] {msg}"
    print(entry)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(entry + "\n")
    except Exception:
        pass

def main():
    username = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("USER", "sukrutmannari")
    script_dir = os.path.dirname(os.path.abspath(__file__))
    home = os.path.expanduser("~")
    
    candidate_template_dirs = [
        os.path.join(script_dir, "templates"),
        os.path.join(home, ".macfaceid", "templates"),
        "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID/templates"
    ]
    
    template_path = None
    for c_dir in candidate_template_dirs:
        candidate_path = os.path.join(c_dir, f"{username}.npy")
        if os.path.exists(candidate_path):
            template_path = candidate_path
            break
            
    log(f"Starting verification for user: {username}")
    
    if template_path is None or not os.path.exists(template_path):
        log(f"Error: No face template found for {username} in candidate dirs: {candidate_template_dirs}")
        sys.exit(2)
        
    try:
        raw_template = np.load(template_path)
        if raw_template.ndim == 1:
            templates = [raw_template.reshape(1, 128)]
        elif raw_template.ndim == 2:
            if raw_template.shape[1] == 128:
                templates = [raw_template[i:i+1, :] for i in range(raw_template.shape[0])]
            else:
                templates = [raw_template]
        else:
            templates = [raw_template]
        log(f"Loaded {len(templates)} template embedding(s) for {username}")
    except Exception as e:
        log(f"Error loading template: {e}")
        sys.exit(2)
        
    # Threshold setup
    try:
        timeout = float(sys.argv[2]) if len(sys.argv) > 2 else 6.0
    except (ValueError, IndexError):
        timeout = 6.0
        
    # Match threshold: default 0.34 (SFace standard is 0.363, 0.34 accounts for lighting variation)
    threshold = 0.34
    if len(sys.argv) > 3:
        try:
            threshold = float(sys.argv[3])
        except ValueError:
            pass
            
    # Load Models
    candidate_model_dirs = [
        os.path.join(script_dir, "models"),
        os.path.join(home, ".macfaceid", "models"),
        "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID/models"
    ]
    model_dir = candidate_model_dirs[0]
    for m_dir in candidate_model_dirs:
        if os.path.exists(os.path.join(m_dir, "face_detection_yunet_2023mar.onnx")):
            model_dir = m_dir
            break

    detector = cv2.FaceDetectorYN.create(
        os.path.join(model_dir, "face_detection_yunet_2023mar.onnx"),
        "", (320, 320), score_threshold=0.6
    )
    recognizer = cv2.FaceRecognizerSF.create(
        os.path.join(model_dir, "face_recognition_sface_2021dec.onnx"), ""
    )
    
    log(f"Opening camera (timeout={timeout}s, match_threshold={threshold})...")
    cam_start = time.time()
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        log("Cannot open camera")
        sys.exit(2)
        
    cam_init_time = time.time() - cam_start
    log(f"Camera opened in {cam_init_time:.2f}s. Warming up sensors...")
    
    # Warm up: discard first 3 frames so auto-exposure/white balance settles
    frame = None
    for _ in range(3):
        ret, frame = cap.read()
        if not ret:
            time.sleep(0.05)
            
    if frame is not None and frame.shape[0] > 0:
        h, w, _ = frame.shape
        detector.setInputSize((w, h))
        log(f"Sensors ready. Frame resolution: {w}x{h}. Active scanning started.")
    else:
        log("Warning: could not get initial frame dimensions, using 640x480")
        detector.setInputSize((640, 480))
        
    # START THE SCANNING TIMEOUT HERE (after camera is fully warmed up)
    start_time = time.time()
    frame_count = 0
    best_score_seen = -1.0
    
    while time.time() - start_time < timeout:
        ret, frame = cap.read()
        if not ret:
            time.sleep(0.05)
            continue
            
        frame_count += 1
        _, faces = detector.detect(frame)
        if faces is None or len(faces) == 0:
            gamma_table = np.array([((i / 255.0) ** (1.0 / 1.6)) * 255 for i in range(256)]).astype('uint8')
            boosted = cv2.LUT(frame, gamma_table)
            _, faces = detector.detect(boosted)
        
        if faces is not None and len(faces) > 0:
            # Sort faces by area (width * height) descending so foreground user is evaluated first
            sorted_faces = sorted(faces, key=lambda f: f[2] * f[3], reverse=True)
            for idx, face in enumerate(sorted_faces):
                conf = face[-1]
                face_align = recognizer.alignCrop(frame, face)
                face_feature = recognizer.feature(face_align)
                
                # Check against all enrolled template vectors
                scores = [
                    recognizer.match(tmpl, face_feature, cv2.FaceRecognizerSF_FR_COSINE)
                    for tmpl in templates
                ]
                score = max(scores) if scores else 0.0
                if score > best_score_seen:
                    best_score_seen = score
                    
                log(f"Frame #{frame_count}: Face {idx} (det_conf={conf:.2f}, area={face[2]*face[3]:.0f}) -> match_score={score:.4f}")
                
                if score >= threshold:
                    log(f"SUCCESS: Face verified! Score {score:.4f} >= {threshold} (took {time.time()-start_time:.2f}s active scan)")
                    cap.release()
                    sys.exit(0)
                    
        time.sleep(0.05)
        
    log(f"FAILURE: Face verification timed out after {timeout:.1f}s. Frames checked: {frame_count}, Best score seen: {best_score_seen:.4f}")
    cap.release()
    sys.exit(1)

if __name__ == "__main__":
    main()
