def convert_raw_to_txt(raw_file_path, txt_file_path):
    i = 0
    try:
        with open(raw_file_path, "rb") as raw_file:
            with open(txt_file_path, "w") as txt_file:
                while True:
                    # Assuming each value is 4 bytes (32-bit)
                    raw_bytes = raw_file.read(3)
                    if not raw_bytes:
                        break
                    i += 1
                    # Convert bytes to hexadecimal string and write to text file
                    hex_value = raw_bytes.hex()
                    txt_file.write(hex_value + '\n')
        print(i)
        print("Conversion completed successfully!")
    except FileNotFoundError:
        print("Error: File not found.")
    except Exception as e:
        print("An error occurred:", e)


def reconstruct_raw_from_txt(txt_file_path, raw_file_path):
    try:
        with open(txt_file_path, "r") as txt_file:
            with open(raw_file_path, "wb") as raw_file:
                for line in txt_file:
                    hex_value = line.strip()
                    # Convert hexadecimal string to bytes and write to raw file
                    raw_bytes = bytes.fromhex(hex_value)
                    raw_file.write(raw_bytes)
        print("Reconstruction completed successfully!")
    except FileNotFoundError:
        print("Error: File not found.")
    except Exception as e:
        print("An error occurred:", e)


# Example usage:
raw_file_path = r"C:/Users/gilic/OneDrive/EGYETEM/Vik_msc1/scaler_2024_04_11_03_30/scaler/lena_color_512_512_original.raw"
txt_file_path = r"C:/Users/gili/OneDrive/EGYETEM/Vik_msc1/scaler_2024_04_11_03_30/scaler/lena_color.txt"
convert_raw_to_txt(raw_file_path, txt_file_path)
# Example usage:
txt_file_path = r"C:\Users\gilic\OneDrive\EGYETEM\Vik_msc1\scaler_python\lena_out.txt"
raw_file_path = r"C:\Users\gilic\OneDrive\EGYETEM\Vik_msc1\scaler_python\lena_out.raw"
reconstruct_raw_from_txt(txt_file_path, raw_file_path)
