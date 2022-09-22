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


#ifndef _DECODER_H
#define _DECODER_H


typedef struct DecoderRingBuffer {

	uint32_t currentSize;
	uint32_t readIndex, writeIndex;
	uint8_t dataBits[DECODER_BUFFER_CAPACITY];
	bool endOfFile;
	FILE * inputFilePointer;

} DecoderRingBuffer;

bool EOFEncountered(DecoderRingBuffer *buffer);

void FetchData(DecoderRingBuffer *buffer);

bool ReadNewData(DecoderRingBuffer *buffer);

void Decode(StatisticalModel *model, StatisticalModelType modelType, char *inputFilePath, char *outputFilePath);


#endif /* _DECODER_H */
