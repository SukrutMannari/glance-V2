import sys
import os
import cv2
import numpy as np
import time
import subprocess

def play_sound(sound_name):
    sound_path = f"/System/Library/Sounds/{sound_name}.aiff"
    if os.path.exists(sound_path):
        subprocess.Popen(["afplay", sound_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def speak(text):
    subprocess.Popen(["say", "-r", "200", text], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def main():
    username = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("USER", "sukrutmannari")
    script_dir = os.path.dirname(os.path.abspath(__file__))
    home = os.path.expanduser("~")
    
    template_dir = os.path.join(script_dir, "templates")
    os.makedirs(template_dir, exist_ok=True)
    template_path = os.path.join(template_dir, f"{username}.npy")
    preview_path = os.path.join(template_dir, f"preview_{username}.jpg")
    
    # Also ensure user home template dir exists
    home_template_dir = os.path.join(home, ".macfaceid", "templates")
    os.makedirs(home_template_dir, exist_ok=True)
    
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
        "", (320, 320), score_threshold=0.45
    )
    recognizer = cv2.FaceRecognizerSF.create(
        os.path.join(model_dir, "face_recognition_sface_2021dec.onnx"), ""
    )
    
    print(f"=== MacFaceID Interactive Enrollment for {username} ===")
    print("Opening live camera window...")
    print("TIP: Tilt your laptop screen so your face is centered, and look directly at the webcam.")
    
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Error: Could not open webcam.")
        sys.exit(1)
        
    # Warmup
    for _ in range(5):
        cap.read()
        
    ret, frame = cap.read()
    if not ret:
        print("Error: Could not read from webcam.")
        cap.release()
        sys.exit(1)
        
    h, w, _ = frame.shape
    detector.setInputSize((w, h))
    
    window_name = "MacFaceID Enrollment - Look at the Camera"
    cv2.namedWindow(window_name, cv2.WINDOW_AUTOSIZE)
    
    speak("Please adjust your screen and look at the camera")
    
    collected_features = []
    best_preview = None
    last_capture_time = 0.0
    start_time = time.time()
    
    print("\nA window has opened on your screen showing your camera feed.")
    print("Hold still and look directly at the green box.")
    print("Press 'q' in the window at any time to cancel.\n")
    
    while len(collected_features) < 5:
        # 60 second overall timeout
        if time.time() - start_time > 60.0:
            print("\nEnrollment timed out after 60 seconds.")
            break
            
        ret, frame = cap.read()
        if not ret:
            time.sleep(0.05)
            continue
            
        display_frame = frame.copy()
        
        # Mirror display for natural selfie view
        display_frame = cv2.flip(display_frame, 1)
        
        # Detect on the original frame
        _, faces = detector.detect(frame)
        
        # Fallback with shadow boost if strongly backlit
        if faces is None or len(faces) == 0:
            # Quick gamma boost for detection in dark/backlit scenes
            gamma_table = np.array([((i / 255.0) ** (1.0 / 1.6)) * 255 for i in range(256)]).astype('uint8')
            boosted = cv2.LUT(frame, gamma_table)
            _, faces = detector.detect(boosted)
            
        face_found = False
        if faces is not None and len(faces) > 0:
            # Pick largest face
            largest_face = max(faces, key=lambda f: f[2] * f[3])
            area = largest_face[2] * largest_face[3]
            
            # Make sure it's at least a moderate size (foreground)
            if area > (w * h * 0.015):
                face_found = True
                x, y, fw, fh = [int(v) for v in largest_face[:4]]
                
                # Mirror bounding box coordinates for mirrored display
                disp_x = w - (x + fw)
                cv2.rectangle(display_frame, (disp_x, y), (disp_x + fw, y + fh), (0, 255, 0), 2)
                
                # Draw landmarks on display
                for p in range(5):
                    lx = int(largest_face[4 + p * 2])
                    ly = int(largest_face[5 + p * 2])
                    disp_lx = w - lx
                    cv2.circle(display_frame, (disp_lx, ly), 3, (0, 255, 255), -1)
                
                # Capture frame if 0.4s has passed since last sample
                if time.time() - last_capture_time >= 0.45:
                    face_align = recognizer.alignCrop(frame, largest_face)
                    feat = recognizer.feature(face_align)
                    collected_features.append(feat)
                    last_capture_time = time.time()
                    play_sound("Tink")
                    
                    if best_preview is None:
                        best_preview = frame.copy()
                        cv2.rectangle(best_preview, (x, y), (x + fw, y + fh), (0, 255, 0), 2)
                        cv2.putText(best_preview, f"Enrolled: {username}", (x, max(30, y - 10)),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
                        
                    print(f"  [+] Sample {len(collected_features)}/5 captured!")
                    
        # On-screen HUD instructions
        if face_found:
            status_text = f"Capturing: {len(collected_features)}/5 - HOLD STILL"
            cv2.putText(display_frame, status_text, (30, 45),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)
        else:
            status_text = "LOOK UP AT THE WEBCAM (Face Not Centered)"
            cv2.putText(display_frame, status_text, (30, 45),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.75, (0, 165, 255), 2)
            cv2.putText(display_frame, "Tilt screen so your eyes & nose are visible", (30, 80),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 1)
            
        progress_w = int((len(collected_features) / 5.0) * (w - 60))
        cv2.rectangle(display_frame, (30, h - 35), (w - 30, h - 20), (50, 50, 50), -1)
        if progress_w > 0:
            cv2.rectangle(display_frame, (30, h - 35), (30 + progress_w, h - 20), (0, 255, 0), -1)
            
        cv2.imshow(window_name, display_frame)
        key = cv2.waitKey(20) & 0xFF
        if key == ord('q') or key == 27: # q or Esc
            print("\nEnrollment canceled by user.")
            break
            
    cap.release()
    cv2.destroyAllWindows()
    cv2.waitKey(1)
    
    if len(collected_features) >= 3:
        feature_matrix = np.vstack(collected_features)
        np.save(template_path, feature_matrix)
        home_template_path = os.path.join(home_template_dir, f"{username}.npy")
        try:
            np.save(home_template_path, feature_matrix)
        except Exception:
            pass
        if best_preview is not None:
            cv2.imwrite(preview_path, best_preview)
            try:
                cv2.imwrite(os.path.join(home_template_dir, f"preview_{username}.jpg"), best_preview)
            except Exception:
                pass
            
        play_sound("Glass")
        speak("Face enrolled successfully")
        print("\n" + "=" * 50)
        print(" SUCCESS! Face template enrolled.")
        print(f" Template saved: {template_path}")
        print(f" Captured {len(collected_features)} high-resolution feature vectors.")
        print("=" * 50)
        sys.exit(0)
    else:
        print("\n" + "!" * 50)
        print(" Failed: insufficient face samples captured.")
        print(" Please ensure your face is well-lit and facing the camera.")
        print("!" * 50)
        sys.exit(1)

if __name__ == "__main__":
    main()
