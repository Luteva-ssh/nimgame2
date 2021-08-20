# nimgame2/perspectiveimage.nim
# Copyright (c) 2016-2018 Vladimir Arabadzhi (Vladar)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# vladar4@gmail.com
# https://github.com/Vladar4

import
  math,
  sdl2_nim/sdl,
  sdl2_nim/sdl_image as img,
  settings, types


type
  PerspectiveDirection* = enum pdHor, pdVer

  PerspectiveImage* = ref object of RootObj
    # Private
    fDim: Dim
    fSurface: Surface   ## Source surface


#==================#
# PerspectiveImage #
#==================#

proc free*(image: PerspectiveImage) =
  if not (image.fSurface == nil):
    image.fSurface.freeSurface()


proc init*(image: PerspectiveImage) =
  image.free()
  image.fSurface = nil


template afterLoad(image: PerspectiveImage) =
  image.fDim = (image.fSurface.w.int, image.fSurface.h.int)


proc load*(image: PerspectiveImage,
           file: string): bool =
  ##  Load ``image`` graphic source from a ``file``.
  ##
  result = true
  image.free()
  # load image
  image.fSurface = img.load(file)
  if image.fSurface == nil:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't load perspective image %s: %s",
                    file, img.getError())
    return false
  # after-load
  afterLoad(image)


proc load*(image: PerspectiveImage,
           src: ptr RWops, freeSrc: bool = true): bool =
  ##  Load ``image`` graphic source from a ``src`` ``RWops``.
  ##
  result = true
  image.free()
  # load image
  image.fSurface = img.loadRW(src, freeSrc)
  if image.fSurface == nil:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't load perspective image RW: %s",
                    img.getError())
    return false
  # after-load
  afterLoad(image)


proc newPerspectiveImage*(): PerspectiveImage =
  new result, free
  result.init()


proc newPerspectiveImage*(file: string): PerspectiveImage =
  ##  Create a new PerspectiveImage and load it from a ``file``.
  ##
  result = newPerspectiveImage()
  discard result.load(file)


proc newPerspectiveImage*(
    src: ptr RWops, freeSrc: bool = true): PerspectiveImage =
  ##  Create a new PerspectiveImage and load it from a ``src`` ``RWops``.
  ##
  result = newPerspectiveImage()
  discard result.load(src, freeSrc)


proc dim*(image: PerspectiveImage): Dim {.inline.} =
  image.fDim


proc render*(image: PerspectiveImage,
             direction: PerspectiveDirection,
             sizeFrom, sizeTo: int,
             sizeNormal: int = 0,
             shift: float = 0.5): Texture =
  ##  ``direction`` (`pdHor` or `pdVer`) direction of perspective axis.
  ##
  ##  ``sizeFrom``, ``sizeTo`` target scaled size
  ##  (left and right for the `pdHor`, or top and bottom for the `pdVer`).
  ##
  ##  ``sizeNormal`` scaled size of the normal axis.
  ##
  ##  ``shift`` perspective shift (0.5 is center symmetry).
  ##
  ##  ``Return`` a new ``Texture`` created from the ``image``.
  ##
  let
    sizeFrom =
      if sizeFrom > 0:
        sizeFrom
      else:
        case direction:
        of pdHor: image.fDim.h
        of pdVer: image.fDim.w

    sizeTo =
      if sizeTo > 0:
        sizeTo
      else:
        case direction:
        of pdHor: image.fDim.h
        of pdVer: image.fDim.w

    sizeNormal =
      if sizeNormal > 0:
        sizeNormal
      else:
        case direction:
        of pdHor: image.fDim.w
        of pdVer: image.fDim.h

    maxSize = max(sizeFrom, sizeTo)

    (sw, sh) = case direction:
      of pdHor: (sizeNormal, maxSize)
      of pdVer: (maxSize, sizeNormal)

    sizeStep = (sizeFrom - sizeTo) / sizeNormal

    normalStep = case direction:
      of pdHor: image.fDim.w / sizeNormal
      of pdVer: image.fDim.h / sizeNormal

    startShift = if sizeFrom > sizeTo: 0
                 else: cint(float(sizeTo - sizeFrom) * shift)

  # create a temporary surface
  var surface: Surface = createRGBSurfaceWithFormat(
    0, sw, sh,
    image.fSurface.format.BitsPerPixel.cint,
    image.fSurface.format.format)

  if surface == nil:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't create a surface: %s",
                    sdl.getError())
    return nil

  # rect
  var
    (srcRect, dstRect) = case direction:
      of pdHor:
        (
          Rect(x: 0, y: 0, w: cint(round(normalStep)), h: image.fDim.h),
          Rect(x: 0, y: 0, w: 1, h: sizeFrom)
        )
      of pdVer:
        (
          Rect(x: 0, y: 0, w: image.fDim.w, h: cint(round(normalStep))),
          Rect(x: 0, y: 0, w: sizeFrom, h: 1)
        )

  # blit loop
  for i in 0..<sizeNormal:
    case direction:
    of pdHor:
      srcRect.x = cint(round(i.float * normalStep))
      dstRect.x = i
      dstRect.h = sizeFrom - cint(round(sizeStep * i.float))
      dstRect.y = startShift + cint(round(sizeStep * i.float * shift))
    of pdVer:
      srcRect.y = cint(round(i.float * normalStep))
      dstRect.y = i
      dstRect.w = sizeFrom - cint(round(sizeStep * i.float))
      dstRect.x = startShift + cint(round(sizeStep * i.float * shift))
    # blit
    discard image.fSurface.blitScaled(addr(srcRect), surface, addr(dstRect))

  # return and free
  result = renderer.createTextureFromSurface(surface)
  surface.freeSurface()

