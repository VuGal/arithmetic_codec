#ifndef _COMMONS_H
    #include "Commons.h"
#endif /* _COMMONS_H */


#ifndef _STATISTICS_H
#define _STATISTICS_H


extern uint64_t StatisticsReadCounter[NUM_OF_SYMBOLS];
extern uint64_t StatisticsWriteCounter[NUM_OF_SYMBOLS];


double CalculateAverageCodewordLength();

double CalculateCompressionRatio();

double CalculateCompressionRatioWithSemiadaptiveModelOverhead();


#endif /* _STATISTICS_H */
