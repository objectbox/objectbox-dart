# objectbox_demo_desktop

## Getting Started

In this early demo version, only desktop environments are supported. Mobile platform support, i.e. Android and iOS, will be added later. The current code is based on Google's [flutter-desktop-embedding](https://github.com/google/flutter-desktop-embedding) repository.

If you have never run Flutter on desktop before, execute the following commands (these are for Linux, adjust accordingly for your OS, see [here](https://github.com/flutter/flutter/wiki/Desktop-shells#tooling)):

    flutter channel master
    flutter upgrade
    flutter config --enable-linux-desktop

When trying out this demo for the first time, you definitely need to run:

    flutter packages get

And on first run and whenever you added or changed any classes annotated with ObjectBox's `@Entity()`, execute:

    flutter pub run build_runner build
    flutter run
