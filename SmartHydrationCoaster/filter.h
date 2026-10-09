#ifndef FILTER_H
#define FILTER_H

#include <stddef.h>

class MovingAverageFilter {
public:
    explicit MovingAverageFilter(size_t windowSize = 10)
        : maxWindow(windowSize > MAX_CAPACITY ? MAX_CAPACITY : windowSize),
          head(0),
          count(0),
          runningSum(0.0f) {
        for (size_t i = 0; i < MAX_CAPACITY; ++i) {
            buffer[i] = 0.0f;
        }
    }

    void add(float sample) {
        if (count < maxWindow) {
            buffer[head] = sample;
            runningSum += sample;
            count++;
            head = (head + 1) % maxWindow;
        } else {
            runningSum -= buffer[head];
            buffer[head] = sample;
            runningSum += sample;
            head = (head + 1) % maxWindow;
        }
    }

    float getAverage() const {
        if (count == 0) return 0.0f;
        return runningSum / static_cast<float>(count);
    }

    bool isFilled() const {
        return count >= maxWindow;
    }

    void reset() {
        head = 0;
        count = 0;
        runningSum = 0.0f;
        for (size_t i = 0; i < MAX_CAPACITY; ++i) {
            buffer[i] = 0.0f;
        }
    }

private:
    static const size_t MAX_CAPACITY = 20;
    size_t maxWindow;
    size_t head;
    size_t count;
    float runningSum;
    float buffer[MAX_CAPACITY];
};

#endif
