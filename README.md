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

    $ pod generator spec_name

Add source files to existed project, which from podspec at current directory.
Please Be Careful: 
* Please make sure the **target** to be added equal to **spec_name**, else a target with spec_name will be created. 
* Please make sure project name same to spec_name, else can't find *.xcodeproj file.
