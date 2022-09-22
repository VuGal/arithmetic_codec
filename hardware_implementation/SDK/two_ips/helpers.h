#ifndef __HELPERS_H_
#define __HELPERS_H_

#define EOF_SYMBOL 256
#define ENCODER_MODE 0
#define DECODER_MODE 1

#include "xuartps_hw.h"


u8 isReceiveBufferNonEmpty(void);

u32 receiveSymbol(u8 mode);


#endif /* __HELPERS_H_ */
