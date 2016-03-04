# cocoapods-generator

Now, you can add files to empty target with *.podspec, while config it, such as souce files, libraries, frameworks, resources and so on.

**Before use this command:**

![](https://github.com/zhzhy/cocoapods-generator/blob/master/Resoures/Before.png )

**After use this command:**

![](https://github.com/zhzhy/cocoapods-generator/blob/master/Resoures/After.png )
Then you can see source files, vendored framework, resouce files which at current directory will be added to the target.

In the future, the future when no target name same as project will generate a target will be developed, then config it with *.podspec at current directory.

## Installation

    $ gem install cocoapods-generator

## Usage

    $ pod spec generator *.podspec
Please run this command at project root directory, then a target same as podspec name will be configed,
please make sure the target to be configured has same name with podspec.
