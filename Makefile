WORKSPACE := 'MergePDF.xcworkspace'
PRODUCT_NAME := MergePDF
CONFIG := Release

.PHONY:install clean build trash

default: trash clean install

trash:
	trash "${HOME}/Applications/$(PRODUCT_NAME).app"

install:
	xcodebuild -workspace $(WORKSPACE) -scheme "$(PRODUCT_NAME)" -configuration $(CONFIG) install DSTROOT=${HOME}

clean:
	xcodebuild -workspace $(WORKSPACE) -scheme "$(PRODUCT_NAME)" -configuration $(CONFIG) clean

build:
	xcodebuild -workspace $(WORKSPACE) -scheme "$(PRODUCT_NAME)" -configuration $(CONFIG) build
