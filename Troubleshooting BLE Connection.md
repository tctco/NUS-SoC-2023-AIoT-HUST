# Troubleshooting BLE Connection

> Cheng Tang[^*], Yangming Jin[^+], Wenbo Wu[^+], Qinxin Hu[^+]
>
> AIoT Group7, NUS SoC Summer Workshop 2023

Before starting, we recommend to reconsider if it is necessary to connect Micro:bit chips with Raspberry Pi via Bluetooth since radio could be more stable. If you wish to fully exploit the possibility of all Micro:bit chips and also looking for a more elegant solution with the BLE devices, then the following notes might be helpful. 

Another thing worth noting before diving into the details is that *pair* and *connect* are very different things for Bluetooth. You always need to first pair a BLE device before connecting it. Once paired, you only need to connect next time unless you choose to manually *forget* the paired device. To make a Micro:bit device ready to pair, please refer to [Pairing via Bluetooth : Help & Support (microbit.org)](https://support.microbit.org/support/solutions/articles/19000051025-pairing-and-flashing-code-via-bluetooth).

Also, turn on `无需配对：任何人都可以通过蓝牙连接` in your `makecode` editor to save you some trouble.

## Detect Micro:bit with Your Smart Phone

Some times you may need to check if the problem is in your Micro:bit or Raspberry Pi. You may need to use your smart phone or your laptop to check if your Micro:bit has Bluetooth service turned on A common problem is that your smart phone (like iPhone) or your laptop (with Windows OS) cannot find Micro:bit devices. This is because the common Bluetooth is quite different from Bluetooth Low Energy (BLE), which is used in Micro:bit, and your devices such as iPhone may not detect or display any BLE devices. You can find evidence from the [pybluez/pybluez: Bluetooth Python extension module (github.com)](https://github.com/pybluez/pybluez) repo that Bluetooth and BLE have quite different APIs:

```python
# For standard Bluetooth
import bluetooth
nearby_devices = bluetooth.discover_devices(lookup_names=True)
print("Found {} devices.".format(len(nearby_devices)))

# For BLE 
from bluetooth.ble import DiscoveryService
service = DiscoveryService()
devices = service.discover(2)
```

If you have an android phone, you can download the `SmartBond` app from google play. You should be able to find your Micro:bit device with `SmartBond`:

<img src="https://raw.githubusercontent.com/tctco/ImgHosting/master/_-497189378_Screenshot_2023-07-28-21-19-40-471_com.renesas.smartbond_1690550380000_wifi_0.jpg" style="max-width:300px;"/>

The `SmartBond` app also monitors services like accelerometer and UART on the Micro:bit. Check the detail page of your device after you **pair & connect your Micro:bit with your phone**:

<img src="https://raw.githubusercontent.com/tctco/ImgHosting/master/smartbond.gif" style="max-width:300px;"/>

As you can see from the GIF, the accelerometer service with UUID starting with `e95d0...` is working properly. You can check the UUID-service table by looking up Prof. Tan's slides or refer to this website: [Bluetooth Developer Studio - Profile Report (lancaster-university.github.io)](https://lancaster-university.github.io/microbit-docs/resources/bluetooth/bluetooth_profile.html).

## Cannot Find Micro:bit Device with bluetoothctl

TL; DR: Use [bleak](https://bleak.readthedocs.io/en/latest/) to save your life.

```python
from bleak import BleakScanner, BLEDevice
import asyncio
from typing import List

devices: List[BLEDevice] = asyncio.run(BleakScanner.discover(timeout=SCAN_TIME))
```

This is dead easy.

The following content are things we tried, which may be helpful if you wish to dig into this problem.

```bash
bluetoothctl scan on | grep <Your Micro:bit device name>
```

A common problem is that the above command does not give any result on your Raspberry Pi. The `bluetoothctl scan on` command should be able to detect the Micro:bit device whether paired or not, just like `SmartBond`. In this case, you can try `sudo hcitool lescan`. This should be able to find your Micro:bit devices.

However, please note that scanning for BLE devices is still quite buggy, and `hcitool` has already been deprecated so that you may encounter a lot of different bugs... For the debugging purpose, we recommend using `btmon` to monitor Bluetooth scanning and connection. For more details please refer to [linux - Where to find further BlueZ logging and debugging output - Stack Overflow](https://stackoverflow.com/questions/63464160/where-to-find-further-bluez-logging-and-debugging-output) and [man btmon (1): Bluetooth monitor (manpages.org)](https://manpages.org/btmon).

We are not sure why sometimes `bluetoothctl` cannot detect the Micro:bit device. By analyzing the log, we noticed that a `Device Found Event` actually triggered when scanning for the Micro:bit. We did some research and noticed that some people argue that it is possibly a peripheral device problem that the Micro:bit failed to answer the Raspberry Pi in time, but we did not keep a record for reference.

## Failed to Connect to Micro:bit

Several reasons might contribute to this problem:

- Some people argue that there is a conflict between Bluetooth service and the WiFi service on Raspberry Pi because they share the same chip [Bluez can't connect permanently to a Bluetooth LE remote “Function not implemented (38)” · Issue #172 · bluez/bluez (github.com)](https://github.com/bluez/bluez/issues/172)
- Another assumption is that WiFi 2.4GHz has conflicts with Bluetooth as they share the same bandwidth [How To Fix Wireless Interference with Wi-Fi and Bluetooth (nerdstogo.com)](https://www.nerdstogo.com/blog/2019/july/how-to-fix-wireless-interference-with-wi-fi-and-/#:~:text=If you are noticing Bluetooth,router only offers 2.4GHz.)
- Prof. Tan also made a good point that there may just be too many Bluetooth devices and WiFi signals in the classroom and they interfere with each other. We tried to pair and connect Micro:bit in our dorm and everything works like a charm.

Unfortunately, we haven't find any elegant solution. Switching to 5GHz WiFi may help address this issue. What we did is to continuously retry connecting to the Micro:bit device, and we proved that this solution works with 2.4GHz WiFi. See the code below:

```python
from bluetooth import ble

class MyGATTRequester(ble.GATTRequester):
  ...

class BleUartDevice:
  ...
  def connect(self):
        MAX_RETRY = 20
        self.gattRequester = MyGATTRequester(self.address, False)
        cnt = 0
        exception = None
        while cnt < MAX_RETRY and self.gattRequester.is_connected() == False:
            try:
                self.gattRequester.connect(True, "random")
                self.enable_uart_receive()
            except Exception as e:
                exception = e
                logger.error(f"Failed to connect to {self.address}, type{type(e)}, {e}")
                time.sleep(0.2)
                cnt += 1
        if cnt >= MAX_RETRY and self.gattRequester.is_connected() == False:
            raise exception
  ...
```

In most cases, connection will be established within 20 trials. If you are using `bluetoothctl` or `gatttool` to connect to the Micro:bit, you may need to manually retry connecting, which is quite ugly :(

Please help update this document if you find an elegant solution!

## About the GATT Handle and Service UUID

In a nut shell, you need to know the service GATT handle to use the service on the Micro:bit. This could be quite confusing, and you may turn to Prof. Tan for elaboration or refer to this article [GATT \(Services and Characteristics\) - Getting Started with Bluetooth Low Energy](https://www.oreilly.com/library/view/getting-started-with/9781491900550/ch04.html#gatt_caching).

You can find the service handle with the following code (which is also available in the slides):

```python
bluetoothctl scan on | grep tagug # Your Micro:bit device name
bluetoothctl pair F1:7C:E8:2B:27:61 # Pair with your Micro:bit address
bluetoothctl connect F1:7C:E8:2B:27:61 # Check if you are able to connect to it. RETRY if you can't
bluetoothctl disconnect F1:7C:E8:2B:27:61 

sudo gatttool -I -t random -b F1:7C:E8:2B:27:61 # Use the GATTTool
connect
primary E95D-0753-251D-470A-A062-FA1922DFA9A8 # Refer to the course slides or use this manual at https://lancaster-university.github.io/microbit-docs/resources/bluetooth/bluetooth_profile.html
char-desc 0x002e 0xffff # The above command should give you a handle range. Use char-desc to check its characteristics
```

And this article may also be helpful [bluetooth lowenergy - gatttool difference between --char-desc and --characteristics - Stack Overflow](https://stackoverflow.com/questions/43179225/gatttool-difference-between-char-desc-and-characteristics).



[^*]: Department of Nuclear Medicine, Wuhan Union Hospital, Tongji Medical College
[^+]: School of Computer Science and Technology, Huazhong University of Science and Technology
