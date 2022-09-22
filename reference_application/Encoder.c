#include "Encoder.h"


uint8_t ReadBit(EncoderRingBuffer *buffer) {

	uint8_t bit = buffer->dataBits[buffer->readIndex];
	--(buffer->currentSize);
	buffer->readIndex = (buffer->readIndex + 1) % (ENCODER_BUFFER_CAPACITY);

	return bit;
}

uint8_t ReadByte(EncoderRingBuffer *buffer) {

	uint8_t byte = 0;
	for (uint8_t i = 0; i < 8; ++i)
	{
		uint8_t bit = ReadBit(buffer);
		uint8_t mask = 0x00 | bit;
		mask <<= i;

		byte = byte | mask;
	}

	return byte;

}

void WriteBit(EncoderRingBuffer *buffer, uint8_t bit, uint16_t currentSymbol) {

	++StatisticsWriteCounter[currentSymbol];

    buffer->dataBits[buffer->writeIndex] = bit;
    ++(buffer->currentSize);
	buffer->writeIndex = (buffer->writeIndex + 1) % (ENCODER_BUFFER_CAPACITY);

	if (buffer->currentSize >= ENCODER_BUFFER_CAPACITY) {
		uint8_t byte = ReadByte(buffer);
		fprintf(buffer->outputFilePointer, "%c", (char)byte);
	}

}

void WriteNBits(EncoderRingBuffer *buffer, uint8_t bit, uint32_t n, uint16_t currentSymbol) {

	while (n--) {
		WriteBit(buffer, bit, currentSymbol);
	}

}

void Encode(StatisticalModel *model, StatisticalModelType modelType, char *inputFilePath, char *outputFilePath) {

	FILE * inputFilePointer = fopen(inputFilePath, "rb");						// create the handler for input file
	FILE * outputFilePointer = fopen(outputFilePath, "wb");						// create the handler for output file
	EncoderRingBuffer buffer = {.outputFilePointer = outputFilePointer};		// create a buffer for writing bits to output file

	if (modelType == staticModelType) {
		StaticModelInitializeFrequencies(model, staticModelFrequenciesTable);
	}
	else if (modelType == semiadaptiveModelType) {

		SemiadaptiveModelEncoderInitializeFrequencies(model, inputFilePath);

		// add symbol frequencies as output file "header"
		for (uint16_t symbol = 0; symbol < NUM_OF_SYMBOLS; ++symbol) {
			fwrite(&(model->frequencies[symbol]), 4, 1, outputFilePointer);
		}

	}
	else {
		AdaptiveModelResetFrequencies(model);
	}

	uint64_t a = 0;
	uint64_t b = WHOLE;
	uint64_t w = 0;
	uint32_t s = 0;

	uint16_t symbol = 0;
	uint16_t lastSymbol = 0;

	bool endOfInput = false;

	while (!endOfInput) {

		// read next symbol, if EOF encountered than encode EOF symbol
		if (fread(&symbol, 1, 1, inputFilePointer) != 1) {
			endOfInput = true;
			symbol = MODEL_EOF_SYMBOL;
		}
		else {
			lastSymbol = symbol;
			StatisticsReadCounter[symbol] += 8;
		}

		w = b - a;

		// calculate current a and b values
		b = a + (uint64_t)llround(w * ((double)model->freqEnd[symbol] / model->totalFrequencyCounter));
		a = a + (uint64_t)llround(w * ((double)model->freqBegin[symbol] / model->totalFrequencyCounter));

		// scaling
		while (true)
		{
			if (b < HALF) {			// expand left half of the interval [a = 2a, b = 2b]
				WriteBit(&buffer, 0, lastSymbol);
				WriteNBits(&buffer, 1, s, lastSymbol);
				s = 0;
			}
			else if (a > HALF) {	// expand right half of the interval [a = 2(a-HALF), b = 2(b-HALF)]
				WriteBit(&buffer, 1, lastSymbol);
				WriteNBits(&buffer, 0, s, lastSymbol);
				s = 0;
				a -= HALF;
				b -= HALF;
			}
			else if (a > QUARTER && b < (3 * QUARTER)) {	// expand middle of the current interval [a = 2(a-QUARTER), b = 2(b-QUARTER)]
				++s;
				a -= QUARTER;
				b -= QUARTER;
			}
			else {		// end scaling [one of the interval quarters is contained in the [a, b) interval]
				break;
			}

			a *= 2;
			b *= 2;
		}

		if (modelType == semiadaptiveModelType) {

			// decrement the frequency of already coded symbol to better adjust model for the rest of the file
			SemiadaptiveModelUpdateSymbolFrequency(model, symbol);

		}
		else {

			// increment the frequency of coded symbol
			AdaptiveModelUpdateSymbolFrequency(model, symbol);

		}
	}

	// emit rest of the bits (algorithm ends with "middle" case that needs to be handled)
	++s;

	if (a <= QUARTER) {		// [1/4; 1/2) interval used
		WriteBit(&buffer, 0, lastSymbol);
		WriteNBits(&buffer, 1, s, lastSymbol);
	}
	else {					// [1/2; 3/4] interval used
		WriteBit(&buffer, 1, lastSymbol);
		WriteNBits(&buffer, 0, s, lastSymbol);
	}

	uint8_t lastByte = 0;
	uint8_t bit;
	uint8_t mask;
	uint32_t bitsLeft = buffer.currentSize;

	// emit rest of the bits left in the buffer
	if (bitsLeft != 0) {

		StatisticsWriteCounter[lastSymbol] += (8 - bitsLeft);

		for (uint32_t i = 0; i < bitsLeft; ++i) {
			bit = ReadBit(&(buffer));
			mask = 0x00 | bit;
			mask <<= i;
			lastByte = lastByte | mask;
		}

		for (uint32_t i = bitsLeft; i < 8; ++i) {
			mask = 0x00;
			mask <<= i;
			lastByte = lastByte | mask;
		}

		fprintf(outputFilePointer, "%c", (char)lastByte);

	}

	fclose(inputFilePointer);
	fclose(outputFilePointer);

}
