#include "Decoder.h"


bool EOFEncountered(DecoderRingBuffer *buffer) {

	return ( buffer->endOfFile && (buffer->currentSize == 0) );

}

// fill the ring buffer with symbols from file
void FetchData(DecoderRingBuffer *buffer) {

	uint32_t numOfBits = DECODER_BUFFER_CAPACITY - buffer->currentSize;
	uint32_t numOfBytesToFetch = numOfBits / 8;

	int8_t byte;
	
	for (uint32_t i = 0; i < numOfBytesToFetch; ++i)
	{
		byte = 0;

		if (fread(&byte, 1, 1, buffer->inputFilePointer) != 1) {
			buffer->endOfFile = true;
			return;
		}

		for (uint8_t i = 0; i < 8; i++) {

			uint8_t bit = byte & 0x01;
			buffer->dataBits[buffer->writeIndex] = bit;
			++(buffer->currentSize);
			buffer->writeIndex = (buffer->writeIndex + 1) % (DECODER_BUFFER_CAPACITY);
			byte >>= 1;

		}
	}

}

bool ReadNewData(DecoderRingBuffer *buffer) {

	if ( (buffer->currentSize == 0) && (!buffer->endOfFile) ) {
		FetchData(buffer);	// if buffer is empty, fill it with new data
	}

	if (EOFEncountered(buffer)) {  // return 0 bit in case of EOF
		return 0;
	}
	else {  // read next bit from ring buffer
		uint8_t bit = buffer->dataBits[buffer->readIndex];
		--(buffer->currentSize);
		buffer->readIndex = (buffer->readIndex + 1) % (DECODER_BUFFER_CAPACITY);
		return bit;
	}

}

void Decode(StatisticalModel *model, StatisticalModelType modelType, char *inputFilePath, char *outputFilePath) {

	FILE * inputFilePointer = fopen(inputFilePath, "rb");
	FILE * outputFilePointer = fopen(outputFilePath, "wb");
	DecoderRingBuffer buffer = {.currentSize = 0, .readIndex = 0, .writeIndex = 0, .endOfFile = false,
								.inputFilePointer = inputFilePointer};

	if (modelType == staticModelType) {
		StaticModelInitializeFrequencies(model, staticModelFrequenciesTable);
	}
	else if (modelType == semiadaptiveModelType) {
		SemiadaptiveModelDecoderInitializeFrequencies(model, inputFilePath);
		fseek(inputFilePointer, NUM_OF_SYMBOLS * 4, SEEK_SET);	// move pointer to the start of encoded data (after model information)
	}
	else {
		AdaptiveModelResetFrequencies(model);
	}

	uint32_t z = 0;

	uint8_t i = 1;
	while (i <= (PRECISION-1) && !EOFEncountered(&buffer)) {		// initialize 'z' with as many bits as precision allows
		if (ReadNewData(&buffer)) {		// bit 1 read
			z += PowerOf(2, (PRECISION-1) - i);
		}
		++i;
	}

	uint64_t a = 0;
	uint64_t b = WHOLE;
	uint64_t a0 = 0;
	uint64_t b0 = 0;
	uint64_t w = 0;
	uint16_t symbol = 0;
	uint8_t decoded = 0;
	uint16_t left = 0;
	uint16_t right = 0;

	while (true)
	{
		// find a symbol with binary search
		left = 0;
		right = MODEL_EOF_SYMBOL;
		while (left <= right)
		{
			symbol = (left + right) / 2;
			w = b - a;
			b0 = a + (uint64_t)llround(w * ((double)model->freqEnd[symbol] / model->totalFrequencyCounter));
			a0 = a + (uint64_t)llround(w * ((double)model->freqBegin[symbol] / model->totalFrequencyCounter));

			if (z < a0)
				right = symbol - 1;
			else if (z >= b0)
				left = symbol + 1;
			else // symbol found: a0 <= z < b0
			{
				if (symbol == MODEL_EOF_SYMBOL) {	// when EOF symbol decoded, end the decoder operation
					fclose(inputFilePointer);
					fclose(outputFilePointer);
					return;
				}

				decoded = (uint8_t)symbol;
				fprintf(outputFilePointer, "%c", (char)decoded);	// write decoded symbol to the output file

				a = a0;
				b = b0;

				if (modelType == semiadaptiveModelType) {

					// decrement the frequency of already coded symbol to better adjust model for the rest of the file
					SemiadaptiveModelUpdateSymbolFrequency(model, decoded);

				}
				else {

					// increment the frequency of coded symbol
					AdaptiveModelUpdateSymbolFrequency(model, decoded);

				}

				break;
			}
		}

		// scaling
		while (true) 
		{
			if (b < HALF) {	      // expand left half of the interval [a = 2a, b = 2b]

				// no operation (as multiplication by 2 is done after if clause)

			}
			else if (a > HALF) {  // expand right half of the interval [a = 2(a-HALF), b = 2(b-HALF)]
				a -= HALF;
				b -= HALF;
				z -= HALF;
			}
			else if (a > QUARTER && b < (3 * QUARTER)) {	// expand middle of the current interval [a = 2(a-QUARTER), b = 2(b-QUARTER)]
				a -= QUARTER;
				b -= QUARTER;
				z -= QUARTER;
			}
			else {	// end scaling [one of the interval quarters is contained in the [a, b) interval]
				break;
			}

			a *= 2;
			b *= 2;
			z *= 2;

			// update z approximation
			if (!EOFEncountered(&buffer) && ReadNewData(&buffer)) {
				++z;
			}
		}
	}

}
