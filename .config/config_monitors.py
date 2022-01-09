#!/usr/bin/env python
from os import system
xrandr_bin = '/usr/bin/xrandr'
# monitor_list
# use the format
# 'OUTPUT/INTERFACE': {
#   'mode': '<Mode>',
#   'rate': 'rateHz' <- by default is 60,
#   'other-arg': 'value'
#}

monitor_list = {
    'HDMI-A-1': {
        'mode': '1920x1080',
        'rate': 144
    }
}




if __name__ == '__main__':
    print('Adapting monitors...')

    for output, config in monitor_list.items():
        print(f'Configuring monitor at {output}')
        args = ''
        for cname, value in config.items():
            args += f'--{cname} {value} '
        system(f'{xrandr_bin} --output {output} {args}')


