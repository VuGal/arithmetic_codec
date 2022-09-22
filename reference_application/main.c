#include "Commons.h"
#include "StaticModel.h"
#include "SemiadaptiveModel.h"
#include "AdaptiveModel.h"
#include "Encoder.h"
#include "Decoder.h"
#include "Statistics.h"
#include <time.h>


int main (int argc, char *argv[]) {

	clock_t tic = clock();

	if ( argc != 5 || 
		((strcmp(argv[1], "--encode") != 0) && (strcmp(argv[1], "--decode") != 0)) || 
		((strcmp(argv[2], "--static") != 0) && (strcmp(argv[2], "--semiadaptive") != 0) && (strcmp(argv[2], "--adaptive") != 0)) ) 
	{
		printf("\nWrong parameters given! Usage: .\\ArithmeticCodec.exe [--encode/--decode] [--static/--semiadaptive/--adaptive] [input_file_path] [output_file_path]\n\n");
	}

	StatisticalModel model;
	StatisticalModelType modelType;

	if (strcmp(argv[2], "--static") == 0) {
		modelType = staticModelType;
	}
	else if (strcmp(argv[2], "--semiadaptive") == 0) {
		modelType = semiadaptiveModelType;
	}
	else if (strcmp(argv[2], "--adaptive") == 0) {
		modelType = adaptiveModelType;
	}

	if (strcmp(argv[1], "--encode") == 0) {

		Encode(&model, modelType, argv[3], argv[4]);

		printf("\nSuccessfully encoded the file!\n\n");

		printf("Output file average codeword length: %.2lf bits\n", CalculateAverageCodewordLength());

		printf("Compression ratio: %.5lf\n", CalculateCompressionRatio());

		if (modelType == semiadaptiveModelType) {
			printf("Compression ratio with semiadaptive model overhead: %.5lf\n", CalculateCompressionRatioWithSemiadaptiveModelOverhead());
		}

		clock_t toc = clock();
		printf("Execution time: %0.3f seconds\n\n", (double)(toc-tic)/CLOCKS_PER_SEC);

		return 0;

	}
	else if (strcmp(argv[1], "--decode") == 0) {

		Decode(&model, modelType, argv[3], argv[4]);
		printf("\nSuccessfully decoded the file!\n\n");
		clock_t toc = clock();
		printf("Execution time: %0.3f seconds\n\n", (double)(toc-tic)/CLOCKS_PER_SEC);
		return 0;

	}

}
