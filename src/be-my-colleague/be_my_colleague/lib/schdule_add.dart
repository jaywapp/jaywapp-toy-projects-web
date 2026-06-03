import 'package:be_my_colleague/data/data_center.dart';
import 'package:be_my_colleague/model/schedule.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduleAddBlock extends StatefulWidget {
  final String clubID;
  final DataCenter dataCenter;

  const ScheduleAddBlock({Key? key, required this.clubID, required this.dataCenter}) : super(key: key);

  @override
  _ScheduleAddBlockState createState() => _ScheduleAddBlockState();
}

class _ScheduleAddBlockState extends State<ScheduleAddBlock> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  // 날짜 선택 메서드
  Future<void> _pickDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate; // 선택된 날짜를 상태로 저장
      });
    }
  }

  // 시간 선택 메서드
  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        selectedTime = pickedTime; // 선택된 시간을 상태로 저장
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('일정 추가'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: '일정의 이름을 입력해주세요.'),
            ),
            TextField(
              controller: locationController,
              decoration: InputDecoration(labelText: '일정 장소의 주소를 입력해주세요.'),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: '일정에 대한 간단한 설명을 적어주세요.'),
            ),
            TextField(
              controller: contentController,
              decoration: InputDecoration(labelText: '일정 내용을 적어주세요.'),
            ),
            SizedBox(height: 16.0),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _pickDate(context),
                    child: Text(
                      selectedDate == null
                          ? '날짜 선택'
                          : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                SizedBox(width: 16.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _pickTime(context),
                    child: Text(
                      selectedTime == null
                          ? '시간 선택'
                          : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
            Spacer(),
           Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: ()  async{
                      // 일정 추가 버튼 클릭 시 처리할 로직 추가
                      final name = nameController.text;
                      final location = locationController.text;
                      final description = descriptionController.text;
                      final content = contentController.text;
                      final dateTime = new DateTime(
                          selectedDate?.year ?? 1000, 
                          selectedDate?.month ?? 1,  
                          selectedDate?.day ?? 1,
                          selectedTime?.hour ?? 0,
                          selectedTime?.minute ?? 0,
                          0);

                      var id = DateFormat('yyyyMMddHHmmsss').format(dateTime);
                      var schedule = new Schedule(id, name, description, location, dateTime, content, []);

                      await widget.dataCenter.AddSchdule(widget.clubID, schedule);
            
                      Navigator.pop(context); 
                    },
                    child: Text('일정 추가'),
                    style: ElevatedButton.styleFrom(
                    backgroundColor : Colors.blue,
                    foregroundColor : Colors.white,
                    ),
                  ),
                ),
                // backgroundColor: include ? Colors.red : Colors.blue,
                // foregroundColor: include ? Colors.black : Colors.white,
                SizedBox(width: 16.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // 취소 버튼 클릭 시 처리할 로직
                      Navigator.pop(context); // 페이지 닫기 예시
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black ,
                      backgroundColor: Colors.red, // 취소 버튼 색상 변경
                    ),
                    child: Text('취소'),
                  ),
                ),
              ],
            ),
           ],
        ),
      ),
    );
  }
}

