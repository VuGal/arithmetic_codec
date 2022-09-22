#include "Commons.h"


void UpdateStatisticalModel(StatisticalModel *model) {

    uint32_t prevFrequency = 0;

    for (uint16_t symbol = 0; symbol < MODEL_SIZE; ++symbol) {
        model->freqBegin[symbol] = prevFrequency;
        prevFrequency += model->frequencies[symbol];
        model->freqEnd[symbol] = prevFrequency;         // interval end = interval begin + frequency
    }

}

void HalveFrequenciesInStatisticalModel(StatisticalModel *model) {

    model->totalFrequencyCounter = 0;
    for (uint32_t i = 0; i < MODEL_SIZE; ++i) {

        // halve all symbol frequencies, but prevent setting them to 0
        if (model->frequencies[i] != 0) {
            model->frequencies[i] = model->frequencies[i] / 2 != 0 ? model->frequencies[i] / 2 : 1;
        }
        model->totalFrequencyCounter += model->frequencies[i];

    }

}

uint64_t PowerOf(uint64_t a, uint64_t n) {

	return n == 0 ? 1 : a * PowerOf(a, n - 1);

}
