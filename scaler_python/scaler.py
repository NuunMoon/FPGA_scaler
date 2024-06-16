import numpy as np
import math


def bl_resize(original_img, new_h, new_w):
    # get dimensions of original image
    old_h, old_w = original_img.shape
    # create an array of the desired shape.
    resized = np.zeros((new_h, new_w))
    # Calculate width and height scaling factors
    w_scale_factor = (old_w) / (new_w)
    h_scale_factor = (old_h) / (new_h)

    print(w_scale_factor)
    print(h_scale_factor)
    for i in range(new_h):
        for j in range(new_w):
            # map the coordinates back to the original image
            x = i * h_scale_factor
            y = j * w_scale_factor
            # calculate the coordinate values for 4 surrounding pixels.
            x_floor = math.floor(x)
            x_ceil = min(old_h - 1, math.ceil(x))
            y_floor = math.floor(y)
            y_ceil = min(old_w - 1, math.ceil(y))
            # get the neighbouring pixel values
            v1 = original_img[x_floor, y_floor]
            v2 = original_img[x_ceil, y_floor]
            v3 = original_img[x_floor, y_ceil]
            v4 = original_img[x_ceil, y_ceil]
            # Estimate the pixel value q using pixel values of neighbours
            print(x_ceil - x)
            print(y_ceil - y)
            q1 = v1 * (x_ceil - x) + v2 * (x - x_floor)
            q2 = v3 * (x_ceil - x) + v4 * (x - x_floor)
            q = q1 * (y_ceil - y) + q2 * (y - y_floor)
            resized[i, j] = q
    return resized


if __name__ == "__main__":

    orig = np.matrix([[1, 2, 3, 4, 5, 6, 7, 8], [1, 2, 3, 4, 5, 6, 7, 8], [
                     1, 2, 3, 4, 5, 6, 7, 8], [1, 2, 3, 4, 5, 6, 7, 8]])
    tf = bl_resize(orig, 7, 12)
    print(orig)
    print(tf)
