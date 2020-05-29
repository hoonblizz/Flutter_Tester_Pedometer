class TimeConverter {

  String makeTwoDigits(String str) {
    return str.padLeft(2, '0');
  }
  String fromDateTime(DateTime time) {
    return '${time.year}-${makeTwoDigits(time.month.toString())}-${makeTwoDigits(time.day.toString())} ${makeTwoDigits(time.hour.toString())} : ${makeTwoDigits(time.minute.toString())} : ${makeTwoDigits(time.second.ceil().toString())}';
  }

  String calcDuration(Duration duration) {   // in mil seconds
  

  String twoDigitMinutes = makeTwoDigits(duration.inMinutes.remainder(60).toString());
  String twoDigitSeconds = makeTwoDigits(duration.inSeconds.remainder(60).toString());
  return "${makeTwoDigits(duration.inHours.toString())}:$twoDigitMinutes:$twoDigitSeconds";

    // int inH;
    // int inM;
    // int inS = ((to - from) / 1000).floor();

    // if(inS >= 60) {
    //   inM = (inS / 60).floor();
    //   inS = inS % 60;

    //   if(inM >= 60) {
    //     inH = (inM / 60).floor();
    //     inM = inM % 60;

    //     return '$inH hour(s)';
    //   }

    //   return '${inM}m ${inS}s';
    // } 

    // return '${inS}s';
  }
} 