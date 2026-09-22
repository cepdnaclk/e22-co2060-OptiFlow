import 'package:flutter/material.dart';
import 'theme.dart';

class MobileCalendarScreen extends StatefulWidget {
  const MobileCalendarScreen({super.key});

  @override
  State<MobileCalendarScreen> createState() => _MobileCalendarScreenState();
}

class _MobileCalendarScreenState extends State<MobileCalendarScreen> {
  final DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // Helper to get days in month
  int _getDaysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(_focusedDay.year, _focusedDay.month);
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthName = _getMonthName(_focusedDay.month);

    return Scaffold(
      backgroundColor: MobileTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '$monthName ${_focusedDay.year}'.toUpperCase(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- FULL MONTH GRID ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MobileTheme.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _buildWeekdayHeader(),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: daysInMonth + (firstDayOfMonth.weekday - 1),
                    itemBuilder: (context, index) {
                      if (index < firstDayOfMonth.weekday - 1) {
                        return const SizedBox(); // Empty space for previous month days
                      }
                      final day = index - (firstDayOfMonth.weekday - 2);
                      bool isSelected =
                          day == _selectedDay.day &&
                          _focusedDay.month == _selectedDay.month;
                      bool isToday =
                          day == DateTime.now().day &&
                          _focusedDay.month == DateTime.now().month;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDay = DateTime(
                              _focusedDay.year,
                              _focusedDay.month,
                              day,
                            );
                          });
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? MobileTheme.neonBlue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isToday && !isSelected
                                ? Border.all(
                                    color: MobileTheme.neonBlue,
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Text(
                            day.toString(),
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- SCHEDULE FOR SELECTED DAY ---
            Text(
              "SCHEDULE: ${_selectedDay.day} $monthName",
              style: const TextStyle(
                color: Colors.blueGrey,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildScheduleItem(
              "09:00 AM",
              "Maintenance",
              "Check Press 02",
              Colors.greenAccent,
            ),
            _buildScheduleItem(
              "01:30 PM",
              "Job #415: Flyer Run",
              "3,000 Units",
              MobileTheme.neonBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: labels
          .map(
            (label) => Text(
              label,
              style: const TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          )
          .toList(),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Widget _buildScheduleItem(
    String time,
    String title,
    String subtitle,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MobileTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 35,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          Text(
            time,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
