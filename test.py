from zeroconf import Zeroconf, ServiceBrowser

class Listener:
    def remove_service(self, zeroconf, type, name):
        pass

    def add_service(self, zeroconf, type, name):
        info = zeroconf.get_service_info(type, name)
        print(f"Service {name} added, info: {info}")

    def update_service(self, zeroconf, type, name):
        pass

zeroconf = Zeroconf()
listener = Listener()
browser = ServiceBrowser(zeroconf, "_remotecontrol._tcp.local.", listener)

import time
time.sleep(2)
zeroconf.close()
