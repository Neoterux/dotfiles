import argparse as ap
from os import system

def make_string(msg, colors):
    cstr = ';'.join(str(color) for color in colors)
    print(f'MESSAGE = {msg}')
    print(f'COLORS = {cstr}')
    ostr = f'\\e[{cstr}m{msg}\\e[0m' 
    print(ostr)
    cmd = f'echo -e \'{ostr}\''

    print(f'TEST COMMAND: {cmd}')
    system(cmd)

if __name__ == '__main__':
    parser = ap.ArgumentParser()
    
    parser.add_argument('-c', '--colors', type=int, nargs='+', dest='colors', required=True)
    parser.add_argument('-t', type=str, dest='msg', required=True)
    args = parser.parse_args()
    
    print(args)
    make_string(args.msg, args.colors)
