// Stream v.1.2
interface IStream
{
public:
   virtual bool GetValues(const int period, const int count, double &val[]) = 0;

   virtual int Size() = 0;
};

class AStream : public IStream
{
protected:
   InstrumentInfo *_symbolInfo;
   ENUM_TIMEFRAMES _timeframe;
   double _shift;

   AStream(InstrumentInfo *symbolInfo, const ENUM_TIMEFRAMES timeframe)
   {
      _shift = 0.0;
      _symbolInfo = symbolInfo;
      _timeframe = timeframe;
   }

   ~AStream()
   {
   }
public:
   void SetShift(const double shift)
   {
      _shift = shift;
   }

   virtual int Size()
   {
      return iBars(_symbolInfo.GetSymbol(), _timeframe);
   }
};