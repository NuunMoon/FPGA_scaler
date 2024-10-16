import numpy as np
from fxpmath import Fxp


if __name__ == "__main__":
    # Example usage
    float_number = [
        [ -0.000000000000000,   0.000000000000000,   1.000000000000000,   0.000000000000000],
        [-0.190476190476190,   0.476190476190476,   0.952380952380952,  -0.238095238095238],
        [-0.238095238095238,   0.952380952380952,   0.476190476190476,  -0.190476190476190]
    ]

    x = Fxp(float_number, signed=True, n_word=12, n_frac=10)
    x.info()
    print(x)
    print(x.bin())
    
    c = Fxp(-0.190476190476190, signed=True, n_word=12, n_frac=10)