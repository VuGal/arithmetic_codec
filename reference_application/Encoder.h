#ifndef _COMMONS_H
    #include "Commons.h"
#endif /* _COMMONS_H */

#ifndef _STATIC_MODEL_H
    #include "StaticModel.h"
#endif /* _STATIC_MODEL_H */

#ifndef _SEMIADAPTIVE_MODEL_H
    #include "SemiadaptiveModel.h"
#endif /* _SEMIADAPTIVE_MODEL_H */

#ifndef _ADAPTIVE_MODEL_H
    #include "AdaptiveModel.h"
#endif /* _ADAPTIVE_MODEL_H */

#ifndef _STATISTICS_H
    #include "Statistics.h"
#endif /* _STATISTICS_H */


#ifndef _ENCODER_H
#define _ENCODER_H


typedef struct EncoderRingBuffer {

	uint32_t currentSize;
	uint32_t readIndex, writeIndex;
    uint8_t dataBits[ENCODER_BUFFER_CAPACITY];
    FILE * outputFilePointer;

} EncoderRingBuffer;

uint8_t ReadBit(EncoderRingBuffer *buffer);

uint8_t ReadByte(EncoderRingBuffer *buffer);

void WriteBit(EncoderRingBuffer *buffer, uint8_t bit, uint16_t currentSymbol);

void WriteNBits(EncoderRingBuffer *buffer, uint8_t bit, uint32_t n, uint16_t currentSymbol);

void Encode(StatisticalModel *model, StatisticalModelType modelType, char *inputFilePath, char *outputFilePath);


#endif /* _ENCODER_H */
