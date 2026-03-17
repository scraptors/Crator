import os
from pathlib import Path

def get_seeds():
    seeds_path = Path(os.getcwd()) / 'resources' / 'seeds.txt'
    with open(seeds_path, 'r') as file:
        seeds = file.readlines()
        seeds = [seed.strip() for seed in seeds]
    return seeds
