#include "helpers.h"


u8 isReceiveBufferNonEmpty(void) {
	 return XUartPs_IsReceiveData(STDIN_BASEADDRESS);
}

u32 receiveSymbol(u8 mode) {

	u8 recvTriesCounter = 0;

	while (recvTriesCounter != 100) {
		if (isReceiveBufferNonEmpty()) {
			return inbyte();
		}
		else {

			for (int i = 0; i < 100000; ++i) {
				;
			}

			++recvTriesCounter;
		}
	}

	if (mode == ENCODER_MODE) {
		return EOF_SYMBOL;
	}
	else {
		return 0;
	}

}
