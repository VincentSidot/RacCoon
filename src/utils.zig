pub fn clamp(T: type, value: T, min: T, max: T) T {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}
