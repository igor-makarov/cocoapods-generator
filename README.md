# cocoapods-generator

Now, you can add files to empty target with *.podspec, while config it, such as souce files, libraries, frameworks, resources and so on.
![Before use this command](./Resoures/Before)
![After use this command](./Resoures/After)

Next, when no target name same as project will generate a target, then config it with *.podspec at current directory.

## Installation

    $ gem install cocoapods-generator

## Usage

    $ pod spec generator *.podspec
    Please run this command at project root directory, then a target will be configed,
    which name same as project name.
