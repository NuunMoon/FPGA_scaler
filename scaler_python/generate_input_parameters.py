def divide_to_fixed_point(num1, num2):
    # Define the number of integer and fraction bits
    num_integer_bits = 8
    num_fraction_bits = 10

    # Perform division
    result = num1 / num2

    # Extract integer and fractional parts
    integer_part = int(result)
    fractional_part = result - integer_part

    # Convert integer part to binary with leading zeros to fit 4 bits
    integer_part_binary = format(integer_part, '0{}b'.format(num_integer_bits))

    # Convert fractional part to binary with 14 bits
    fractional_part_binary = ''
    for _ in range(num_fraction_bits):
        fractional_part *= 2
        bit = int(fractional_part)
        fractional_part_binary += str(bit)
        fractional_part -= bit

    # Combine integer and fractional parts
    fixed_point_binary = integer_part_binary + fractional_part_binary

    return fixed_point_binary


# X
num1 = int(1280-1)
num2 = int(1920)  # CHANGE ME

result = divide_to_fixed_point(num1, num2)
print("Fixed-point representation of the division result:", result)

# Y
num1 = int(720-1)
num2 = int(1080)  # CHANGE ME

result = divide_to_fixed_point(num1, num2)
print("Fixed-point representation of the division result:", result)
