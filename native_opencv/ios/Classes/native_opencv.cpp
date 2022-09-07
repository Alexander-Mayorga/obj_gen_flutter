#include <opencv2/opencv.hpp>

using namespace cv;
using namespace std;

typedef struct image_data {
    int len;
    uint8_t *data;
} image;

// Avoiding name mangling
extern "C" {
    // Attributes to prevent 'unused' function from being removed and to make it visible
    __attribute__((visibility("default"))) __attribute__((used))
    const char* version() {
        return CV_VERSION;
    }

    __attribute__((visibility("default"))) __attribute__((used))
    image_data* process_image(int32_t len, uint8_t *bytes) {
        vector <uchar> v(bytes, bytes + len - 1);   
        Mat input = imdecode(Mat(v), IMREAD_COLOR);
        Mat reducedBrightness = input * 0.4;
        Mat gray, blur, adaptive, rgbWithGrayscale;
        cvtColor(input, gray, COLOR_BGR2GRAY);
        medianBlur(gray, blur, 5);
        adaptiveThreshold(gray, adaptive, 200, ADAPTIVE_THRESH_GAUSSIAN_C, THRESH_BINARY, 3, 2);
        cvtColor(adaptive, rgbWithGrayscale, COLOR_GRAY2RGB);
        vector<Vec3f> circles;
        HoughCircles(blur, circles, HOUGH_GRADIENT, 1,
                 blur.rows/16,  // change this value to detect circles with different distances to each other
                 100, 30, 1, 20 // change the last two parameters
                // (min_radius & max_radius) to detect larger circles
        );

        for(size_t i = 0; i < circles.size(); i++) {
            Vec3i c = circles[i];
            Point center = Point(c[0], c[1]);
            int radius = c[2];
            circle(rgbWithGrayscale, center, radius, Scalar(255,0,255), -1, FILLED);
        }


        vector <uchar> retv;
        imencode(".jpg", rgbWithGrayscale, retv);

        struct image_data *data = (image_data*)malloc(sizeof(struct image_data));
        data->len = retv.size();
        data->data = (uint8_t*)malloc(sizeof(uint8_t) * data->len);
        memcpy(data->data, retv.data(), retv.size());
        
        return data;
    }
}