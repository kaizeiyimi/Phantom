## IMPORTANT

under developing and testing. not stable.

## Phantom ##

**not only** another wheel for downloading web image. `Phantom` is more than that.

It looks complicate, but just in the UIImageView extension level. other two level is much more simple.
`Downloader` and `DownloaderCache` belong to the base level. they just handle downloading task. `Connector`is an **Optional** level which handles an exclusive task execution. 
each level can **track** the task's excution.

the extension of UIImageView for setting web image is based on Connector.

there are some `functional programming`, but all are easy ones( I don't know much, either).

### requirement ###

**iOS8**, **swift 2** are required. And better use **framework**.

### Quick look ###

#### notice
there are some example implementations such as `PTAttachDefaultIndicator`, `PTAttachDefaultProgress`, `PTFadeIn`, `PTCurlDown`. You can write your own codes to do such things.

#### codes example

some args have default value, check codes for detail.
Have any problem, please read more codes.

* full customise
```swift
imageView.pt_setImageWithURL(GIFURL, 
    placeholder: placeholder,  //default to nil
    downloader: sharedDownloader,  //default to sharedDownloader
    cache: cache,  //default to sharedDownloaderCache, set to nil to cancel cache.
    progress: PTAttachDefaultProgress(toView: imageView),
    decoder: { _, data -> DecodeResult<AnimatedGIFImage> in
        return .Success(data: AnimatedGIFImage(data: data)) // decode as AnimatedGIFImage
    },
    completion: {[weak self] result in
        if case .Success(_, let image) = result {
            self?.imageView.xly_setAnimatedImage(image) // playGIF
        } else {
            self?.imageView.image = wrong
        }
    },
    animations: PTCurlDown(imageView, duration: 0.5)) //animations is default to nil

```

* for `UIImage` use
```swift
imageView.pt_setImageWithURL(localURL, 
    placeholder: placeholder,
    downloader: sharedDownloader,
    cache: cache,
    progress: PTAttachDefaultIndicator(toView: imageView),
    completion: {[weak self] finished in
        if !finished { 
            self?.imageView.image = wrong 
        }
    },
    animations: PTFadeIn(imageView, duration: 0.5))

```
