#include "StaticModel.h"


void StaticModelInitializeFrequencies(StatisticalModel *model, const uint32_t frequenciesTable[MODEL_SIZE]) {

    model->totalFrequencyCounter = 0;

    for (uint16_t i = 0; i < MODEL_SIZE; ++i) {
        model->frequencies[i] = frequenciesTable[i];
        model->totalFrequencyCounter += frequenciesTable[i];
    }

    UpdateStatisticalModel(model);

}
