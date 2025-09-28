import shutil
from ultralytics import YOLO

def main():
    # 1. Load pre-trained YOLOv11 (nano version is faster on CPU)
    model = YOLO("yolo11n.pt")  

    # 2. Train on dataset (update the path below to your dataset)
    model.train(
        data="ASL Dataset.v4-v1-aug-and-prep-with-validation-set.yolov11/data.yaml",  # path to your data.yaml
        epochs=100,       # you can increase to 100 for better results
        imgsz=416,       # smaller image size for faster CPU training
        batch=8,
        device="cpu"
    )

    # 3. Save best model to custom path
    best_model_path = r"runs/detect/train/weights/best.pt"
    custom_save_path = "sign_language_model.pt"
    shutil.copy(best_model_path, custom_save_path)
    print(f"✅ Model saved at: {custom_save_path}")

    # 4. Load trained model for inference
    trained_model = YOLO(custom_save_path)

    # Example: Run on one test image
    #test_img = r"C:\Users\aleen\sign_dataset\test\images\sample.jpg"  # <-- replace with your image
    #results = trained_model(test_img, device="cpu")

    # Print recognized word(s)
    #for r in results:
        #for c in r.boxes.cls:
            #print("Recognized word:", trained_model.names[int(c)])

    # 5. (Optional) Webcam detection
    # trained_model.predict(source=0, show=True, device="cpu")

if __name__ == "__main__":
    main()

