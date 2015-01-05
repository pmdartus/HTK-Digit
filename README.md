# Voice Digit Recognition

Use the HTK toolkit to train a model to recognize the spoken numbers.


## Install

Installation of HTK toolkit differs a lot on every platform. The project comes with a `Vagrantfile` in order to ease the project's setup. Vagrant will provision a virtual machine containing Ubuntu 32bit and also install HTK. Refers to [Vagrant's documentation](https://www.vagrantup.com/) for more details.

Because also of the distribution policy of the HTK, you will have to register on the [website](http://htk.eng.cam.ac.uk/) and download the package. Add the compressed package (`HTK-3.4.1.tar.gz`) in the `provision folder`.

You are now ready to run Vagrant.

```
vagrant up
vagrant ss
cd /vagrant
```


## Usage

You can create a model and train it using the command `./start-htk`. The final model will be stored in the folder `Models/hmm15`
The command will also output accuracy of the trainned model against the `dev` dataset.

## Results

Read the [report](REPORT.md)! ;)
