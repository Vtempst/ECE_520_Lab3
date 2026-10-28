import random
import sys
import pathlib

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    random.seed(42)
    script_dir = pathlib.Path(__file__).resolve().parent
    out_path = script_dir.parent / "sim" / "input_data.txt"
    with open(out_path, "w") as f:
        for _ in range(n):
            data = random.randint(0, 0xFFFF)
            f.write(f"{data:04x}\n")
    print(f"Wrote {n} words to {out_path}")

if __name__ == "__main__":
    main()