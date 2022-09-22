#include "AdaptiveModel.h"


void AdaptiveModelResetFrequencies(StatisticalModel *model) {

    // set all symbol frequencies (including EOF symbol) to 1 (setting to 0 would result in no interval assigned to the symbol)
    for (uint32_t i = 0; i < MODEL_SIZE; ++i) {
        model->frequencies[i] = 1;      
    }

    model->totalFrequencyCounter = MODEL_SIZE;

    UpdateStatisticalModel(model);

}

void AdaptiveModelUpdateSymbolFrequency(StatisticalModel *model, uint16_t symbol) {

    // increments the currently encoded symbol's frequency
    ++model->frequencies[symbol];
    ++model->totalFrequencyCounter;

    if (model->totalFrequencyCounter >= MODEL_MAX_FREQUENCY) {
        HalveFrequenciesInStatisticalModel(model);
    }

    UpdateStatisticalModel(model);

}
