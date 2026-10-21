#ifndef FILTER_H
#define FILTER_H
#include <stddef.h>
// Membutuhkan FILTER_WINDOW_SIZE dari config.h; config.h di-include sebelum berkas ini.
class MovingAverageFilter {
public:
    void add(float sample) {
        if (count == FILTER_WINDOW_SIZE) runningSum -= buffer[head];
        else count++;
        buffer[head] = sample;
        runningSum += sample;
        head = (head + 1) % FILTER_WINDOW_SIZE;
    }
    float getAverage() const {
        if (count == 0) return 0.0f;
        return runningSum / static_cast<float>(count);
    }
    void reset() { head = 0; count = 0; runningSum = 0.0f; }
private:
    size_t head = 0;
    size_t count = 0;
    float runningSum = 0.0f;
    float buffer[FILTER_WINDOW_SIZE] = {};
};
#endif
