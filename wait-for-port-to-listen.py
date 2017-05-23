#!/usr/bin/env python
import socket
import errno
import sys
import time

def wait_net_service(server, port, timeout=None):
    """ Wait for network service to appear 
        @param server: hostname or IP
        @param port: port number to try
        @param timeout: in seconds, if None or 0 wait forever
        @return: True of False, if timeout is None may return only True or
                 throw unhandled network exception
    """
    s = socket.socket()
    if timeout:
        from time import time as now
        # time module is needed to calc timeout shared between two exceptions
        end = now() + timeout

    while True:
        try:
            if timeout:
                next_timeout = end - now()
                if next_timeout < 0:
                    return False
                else:
            	    s.settimeout(next_timeout)
            
            s.connect((server, port))
        
        except (socket.timeout) as err:
            # this exception occurs only if timeout is set
            if timeout:
                return False
      
        except (socket.error) as err:
            # catch timeout exception from underlying network library
            # this one is different from socket.timeout
            time.sleep(1)
        else:
            s.close()
            return True

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: %s server-name port-number timeout" % sys.argv[0])
        sys.exit(1)
    server = sys.argv[1]
    try:
        port = int(sys.argv[2])
    except:
        print("port number must be an integer")
        sys.exit(1)
    timeout = None
    if len(sys.argv) == 4:
        try:
            timeout = int(sys.argv[3])
        except:
            print("timeout must be an integer")
            sys.exit(1)
    open = wait_net_service(server, port, timeout)
    if open:
        sys.exit(0)
    else: 
        sys.exit(1)