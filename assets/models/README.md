# Face recognition model

Place the organization-approved TensorFlow Lite recognition model at:

`assets/models/mobile_facenet.tflite`

The model must be the same model and preprocessing version used to create the
512-value enrollment vectors returned by `biometrics/face/profile`. The app
fails closed when this asset is absent, has an incompatible input/output shape,
or produces a non-finite vector. Do not substitute an unverified model: vectors
from different recognition models are not comparable.
