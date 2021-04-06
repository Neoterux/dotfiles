#!/usr/bin/python3

import argparse as ap
import os

mipmap_variants = ('hdpi', 'mdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi')
pjoin = os.path.join
abspath = os.path.abspath
def joinabs(base, new_dir): return abspath(pjoin(base, new_dir))


def mkdirs(path):
    try:
        os.makedirs(path)
    except FileExistsError:
        pass
        #print(f'dir [{path}] exists, skipping...')


def setup(args):
    base_dir = f'src/{args.lang}/{args.extName.lower()}'
    print(f"base_dir: {base_dir}")
    # Source code directory
    src_dir = f'{base_dir}/src/eu/kanade/tachiyomi/extension/{args.lang}/{args.extName.lower()}'
    source_full_path = joinabs(base_dir, src_dir)

    # Create new extension path
    mkdirs(src_dir)

    # Create extensions resources directory:
    make_res_folder(base_dir)

    if args.extClass == None:
        main_class_file = args.extName.capitalize() + '.kt'
    else:
        main_class_file = args.extClass + '.kt'

    print(f"[DEBUG] ---- SRC DIRECTORY ---- : {src_dir}")
    print(f"[DEBUG] ---- FULL SRC DIRECTORY ---- : {source_full_path}")

    with open(pjoin(src_dir, main_class_file), 'w+', encoding='utf-8') as file:
        file.write('')

    with open(f'{base_dir}/build.gradle', mode='w+', encoding='utf-8') as file:
        file.write(build_gradle(args.extName, args.lang,
                   args.extClass, args.containsNsfw))


def make_res_folder(base_dir):
    print('abs path:', joinabs(base_dir, 'res'))
    res_path = joinabs(base_dir, 'res')
    for var in mipmap_variants:
        var = f'mipmap-{var}'
        print(f'dir of {var}: {pjoin(res_path, var)}')

        mkdirs(pjoin(res_path, var))


def android_manifest():
    return '<?xml version="1.0" encoding="utf-8"?>' + '\n' +\
        '<manifest package="eu.kanade.tachiyomi.extension" />'


def build_gradle(extName: str, lang: str, extClass: str, containsNsfw: bool):
    containsNsfw = str(containsNsfw).lower()
    if (extClass == None):
        extClass = extName.capitalize()
    return "apply plugin: 'com.android.application'\n" + \
        "apply plugin: 'kotlin-android'\n" + \
        "\next {\n" + \
        f"\textName = '{extName}'\n" + \
        f"\tpkgNameSuffix = '{lang}.{extName.lower()}'\n" + \
        f"\textClass = '.{extClass}'\n" + \
        '\textVersionCode = 1\n' + \
        "\tlibVersion = '1.0'\n" + \
        f'\tcontainsNsfw = {containsNsfw}\n' + \
        '}\n\n' + \
        'apply from: "$rootDir/common.gradle"'


langs = ('all', 'ar', 'ca', 'de', 'en', 'es', 'fr', 'id',
         'it', 'ja', 'ko', 'pt', 'ru', 'th', 'tr', 'vi', 'zh')

if __name__ == '__main__':
    parse = ap.ArgumentParser()

    parse.add_argument('-n', '--name', type=str, required=True, dest='extName')
    parse.add_argument('-i', '--ext-image', type=str,
                       required=False, dest='extImage')
    # parse.add_argument('-ns', '--name-suffix', type=str,
    #                    required=True, dest='pkgNameSuffix')
    # lang = parse.add_argument_group('Language', required=True)
    # for ln in langs:
    #     lang.add_argument(f'-{ln}', action='store_const', const=ln)

    parse.add_argument('--nsfw', action='store_true', dest='containsNsfw')
    parse.add_argument('-c', '--ext-class', type=str, dest='extClass')
    parse.add_argument('-l', '--language', type=str,
                       choices=langs, required=True, default='en', dest='lang')

    args = parse.parse_args()

    if args.extClass == None:
        args.extClass = args.extName.capitalize()
    print(args)
    setup(args)
    # print(build_gradle(args.extName, args.pkgNameSuffix,
    #       args.extClass, args.containsNsfw))
