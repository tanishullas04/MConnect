import cv2
from ultralytics import YOLO

def main():
    # Load your trained model
    model = YOLO("sign_language_model.pt")

    # Open webcam
    cap = cv2.VideoCapture(0)  # 0 = default camera

    if not cap.isOpened():
        print("❌ Error: Cannot open webcam")
        return

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        # Run YOLO inference
        results = model(frame, device="cpu", verbose=False)

        # Extract detected words
        detected_words = []
        for r in results:
            for c in r.boxes.cls:
                word = model.names[int(c)]
                detected_words.append(word)

        # Overlay recognized words on frame
        if detected_words:
            text = " ".join(set(detected_words))  # show unique predictions
            cv2.putText(frame, f"Word: {text}", (20, 40),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

        # Show results in window
        cv2.imshow("Sign Language to Text", frame)

        # Press 'q' to quit
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
