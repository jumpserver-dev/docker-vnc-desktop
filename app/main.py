#!/usr/bin/env python
# -*- coding: utf-8 -*-


import time


def main():
    
    while 1:
        print("Sleep forerver!")
        time.sleep(60*60*24)


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(e)
