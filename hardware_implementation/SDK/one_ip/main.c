#include "platform.h"
#include "xparameters.h"
#include "xil_io.h"
#include "arithmetic_codec.h"
#include "helpers.h"


/**************************** user definitions ********************************/

// Arithmetic codec base address redefinition
#define ARITHMETIC_CODEC_BASE_ADDR        XPAR_ARITHMETIC_CODEC_0_S00_AXI_BASEADDR

// Arithmetic codec registers' offset redefinition
#define CODEC_INPUT_CONTROLS_REG_OFFSET   ARITHMETIC_CODEC_S00_AXI_SLV_REG0_OFFSET
#define CODEC_INPUT_DATA_REG_OFFSET       ARITHMETIC_CODEC_S00_AXI_SLV_REG1_OFFSET
#define CODEC_OUTPUT_CONTROLS_REG_OFFSET  ARITHMETIC_CODEC_S00_AXI_SLV_REG2_OFFSET
#define CODEC_OUTPUT_DATA_REG_OFFSET	  ARITHMETIC_CODEC_S00_AXI_SLV_REG3_OFFSET

/***************************** Main function *********************************/

int main() {

	init_platform();

	u8 encoderInputByte;
	u32 encoderOutputBytes;
	u32 decoderInputBytes[4];
	u32 decoderOutputBytes;
	u8 validOutputBytes;


	// ENCODER

	encoderInputByte = inbyte();
	ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_DATA_REG_OFFSET, encoderInputByte);
	ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_CONTROLS_REG_OFFSET, 0x1);
	ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_CONTROLS_REG_OFFSET, 0x0);

	while (1) {

		if ((ARITHMETIC_CODEC_mReadReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_OUTPUT_CONTROLS_REG_OFFSET) & 0x4) == 0x4) {
			ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_DATA_REG_OFFSET, receiveSymbol(ENCODER_MODE));
			ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_CONTROLS_REG_OFFSET, 0x4);
			ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_CONTROLS_REG_OFFSET, 0x0);
		}

		if ((ARITHMETIC_CODEC_mReadReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_OUTPUT_CONTROLS_REG_OFFSET) & 0x2) == 0x2) {
			encoderOutputBytes = ARITHMETIC_CODEC_mReadReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_OUTPUT_DATA_REG_OFFSET);
			validOutputBytes = (ARITHMETIC_CODEC_mReadReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_OUTPUT_CONTROLS_REG_OFFSET) & 0x38) >> 3;

			for (int i = 0; i < validOutputBytes; ++i) {
				outbyte(encoderOutputBytes>>(i*8));
			}

			ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_CONTROLS_REG_OFFSET, 0x2);
			ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_CONTROLS_REG_OFFSET, 0x0);
		}

		if ((ARITHMETIC_CODEC_mReadReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_OUTPUT_CONTROLS_REG_OFFSET) & 0x1) != 0)  {
			break;
		}

	}


	// DECODER

	decoderInputBytes[0] = inbyte();

	for (int i = 1; i <= 3; ++i) {
		decoderInputBytes[i] = receiveSymbol(DECODER_MODE);
	}

	ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_DATA_REG_OFFSET,
	decoderInputBytes[0] | (decoderInputBytes[1]<<8) | (decoderInputBytes[2]<<16) | (decoderInputBytes[3]<<24) );
	ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_CONTROLS_REG_OFFSET, 0x9);
	ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_CONTROLS_REG_OFFSET, 0x8);

	while (1) {

		// if new bits requested
		if ((ARITHMETIC_CODEC_mReadReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_OUTPUT_CONTROLS_REG_OFFSET) & 0x4) == 0x4) {

			for (int i = 0; i <= 3; ++i) {
				decoderInputBytes[i] = receiveSymbol(DECODER_MODE);
			}

			ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_DATA_REG_OFFSET,
			decoderInputBytes[0] | (decoderInputBytes[1]<<8) | (decoderInputBytes[2]<<16) | (decoderInputBytes[3]<<24) );
			ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_CONTROLS_REG_OFFSET, 0xC);
			ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_CONTROLS_REG_OFFSET, 0x8);
		}

		// if bits ready on output
		if ((ARITHMETIC_CODEC_mReadReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_OUTPUT_CONTROLS_REG_OFFSET) & 0x2) == 0x2) {
			decoderOutputBytes = ARITHMETIC_CODEC_mReadReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_OUTPUT_DATA_REG_OFFSET);
			validOutputBytes = (ARITHMETIC_CODEC_mReadReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_OUTPUT_CONTROLS_REG_OFFSET) & 0x38) >> 3;

			for (int i = 0; i < validOutputBytes; ++i) {
				outbyte(decoderOutputBytes>>(i*8));
			}

			ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_CONTROLS_REG_OFFSET, 0xA);
			ARITHMETIC_CODEC_mWriteReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_INPUT_CONTROLS_REG_OFFSET, 0x8);
		}

		if ((ARITHMETIC_CODEC_mReadReg(ARITHMETIC_CODEC_BASE_ADDR, CODEC_OUTPUT_CONTROLS_REG_OFFSET) & 0x1) != 0) {
			break;
		}

	}


	/* Failure or end trap */
	FAILURE:
		while(1);

}
