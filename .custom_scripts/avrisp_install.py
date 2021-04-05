#!/usr/bin/python3
from argparse import ArgumentParser
from os import path, system


fuses = { # low, high, extended
    ('dfu', 'atmega32u4'): ('0x5E', '0xD9', '0xC3'),
    ('caterina', 'atmega32u4'): ('0xFF', '0xD8', '0xCB')
}

micro_alias = {
    'm32u4': 'atmega32u4',
    '32u4': 'atmega32u4',
    'atmega32u4': 'atmega32u4'
}



def show_config():
    global args
    print('\n-------------------========[ CONFIGURATION ]========-------------------')
    print(f'Target micro: \t{args.micro}')
    if args.firm != '':
        print(f'Using predefined firmware: {args.firm}')

    print(f'FUSES:\n\tLow Fuse: {args.lfuse} \n\tHigh Fuse: {args.hfuse} \n\tExtended Fuse: {args.efuse} \n\tLock Bit: {args.lockbit}\n')

    print(f'Files to flash:')
    for hexfile in args.target:
        print(f'\t- {hexfile}')
    print('\n------------------=======[ END CONFIGURATION ]=======------------------')


def run():
    global args

    if any(x is None for x in fuses):
        print('Invalid configuration, please set manually ')


    lock = ''
    if args.lockbit != '':
        lock = f'-U lock:w:{args.lockbit}:m'

    for hexfile in args.target:
        print(f'INFO: Executing AVRDUDE for {hexfile}\n')
        system(f'avrdude -c {args.programmer} -P {args.port} -p {args.micro} flash:w:{hexfile}:i -U lfuse:w:{args.lfuse}:m -U hfuse:w:{args.hfuse}:m -U efuse:w:{args.efuse}:m {lock}')



if __name__ == '__main__':
    parser = ArgumentParser(description='Flash hex files easily with ISP Programmer')

    parser.add_argument('-i', '--info', '--show-info', action='store_true', dest='show_info')

    firm = parser.add_mutually_exclusive_group(required=False)
    firm.description = 'select what fuses would like use, default is -----'
    firm.title = 'Firmware'
    firm.add_argument('--firm',  default='', const='', nargs='?', choices=['dfu', 'caterina'], dest='firm', help='predefined firmware fuses values')
    #firm.add_argument('--dfu', dest='DFU-atmel or DFU-qmk firmware', type=bool)
    #firm.add_argument('--caterina', dest='', type=bool)

    prog = parser.add_mutually_exclusive_group(required=False)
    prog.title = 'Programmers'
    prog.description = 'Select what programmer would you use: '
    prog.add_argument('--prog', choices=['avrisp', 'usbtiny', 'buspirate', 'avrispmkii'], default='avrisp', dest='programmer')
    prog.add_argument('--custom-prog', type=str, dest='programmer', help='Custom programmer name', )
    # prog.add_argument('--avrisp', dest='Pro micro, Teensy 2.0, etc.')
    # prog.add_argument('--usb-tiny', dest='SparkFun PocketAVR, USBTinyISP AVR Programmer Kit, etc.')
    # prog.add_argument('--bus-pirate', dest='Bus pirate.')

    fuses_args = parser.add_argument_group()
    fuses_args.title = 'Fuses'
    fuses_args.description = 'Customize fuses values'
    fuses_args.add_argument('-l', '-lf', '--lfuse', dest='lfuse', help='Low fuse in hex value', type=str)
    fuses_args.add_argument('-hf', '--hfuse', dest='hfuse', help='High fise in hex value', type=str)
    fuses_args.add_argument('-e', '-ex', '--exfuse', dest='efuse', help='Extended fuse in hex value', type=str)
    fuses_args.add_argument('-lck', '--lock', dest='lockbit', default='', type=str)


    parser.add_argument('--port', '-P', dest='port', help='Port where ISP Programmer is found, default is: (Linux)/dev/ttyACM0' ,default='/dev/ttyACM0', type=str)
    parser.add_argument('-m', '--micro', dest='micro', help='Especify AVR microcontroller name for avrdude', default='atmega32u4', metavar='micro-name')
    parser.add_argument('-t', '--target', dest='target', help='.hex file target to flash with avrdude', required=True, nargs='+', type=str, metavar='file1.hex')
   
    # parser.add_argument('--show-micros', action=lambda: system('avrdude'))

    #parser.add_argument('--prog', choices=['avrisp', 'usb-tiny'])

    args = parser.parse_args()

    if args.firm != '':
        micro = micro_alias.get(args.micro)
        if micro is None:
            print(f'Warning: No configurations found for {args.micro} and {args.firm}')
        else:
            f = fuses[(args.firm, micro)]
            print(f'INFO: configurations found for {args.micro} and {args.firm}')
            if args.lfuse == None:
                args.lfuse = f[0]
            if args.hfuse == None:
                args.hfuse = f[1]
            if args.efuse == None:
                args.efuse = f[2]
            # print(f'Applied: lfuse: {f[0]} | hfuse: {f[1]} | efuse: {f[2]}\n')

    if args.lfuse == args.hfuse == args.efuse == None:
        print('ERROR: Need to specify fuses values')
        exit()

    #print(args.programmer)
    #print(args)
    if args.show_info:
        show_config()
        pass
    run()
