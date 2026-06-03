import 'package:be_my_colleague/data/data_center.dart';
import 'package:be_my_colleague/model/account.dart';
import 'package:be_my_colleague/model/club.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  final DataCenter dataCenter;
  final String clubID;

  const HomeScreen(this.dataCenter, this.clubID);

  @override
  State<StatefulWidget> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int membersCount = 0;
  int postsCount = 0;

  @override
  void initState() {
    super.initState();

    var club =
        widget.dataCenter.GetClubs().firstWhere((o) => o.id == widget.clubID);

    GetMemberCount(club);
    GetPostsCount(club);
  }

  Future<void> GetMemberCount(Club club) async {
    int count = await widget.dataCenter.GetMemberCount(club.id);
    membersCount = count;
  }

  Future<void> GetPostsCount(Club club) async {
    int count = await widget.dataCenter.GetPostsCount(club.id);
    postsCount = count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: Colors.grey[300],
                  height: 150,
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      "대표 이미지 (상단 이미지)",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                SizedBox(height: 10), // 여백 추가
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 50,
                      child: Column(children: [
                        Text("총 멤버",
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center),
                        Text('$membersCount'),
                      ]),
                    ),
                    Container(
                      height: 30, // Divider의 높이를 설정
                      child: VerticalDivider(
                        color: Colors.grey,
                        thickness: 1,
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 50,
                      child: Column(
                        children: [
                          Text("공지사항 수",
                              style: TextStyle(fontSize: 16),
                              textAlign: TextAlign.center),
                          Text('$postsCount'),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                      onPressed: () {
                        // 가입하기 동작 구현
                      },
                      child: Center(
                        child: Text("가입하기",
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center),
                      )),
                ),
                // 게시물 리스트
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.all(8),
                    children: [
                      buildPostItem(
                          "게시물 제목 1", "작성자: 홍길동", "24.10.01", "조회수: 123"),
                      buildPostItem(
                          "게시물 제목 2", "작성자: 아무개", "24.10.02", "조회수: 99"),
                      buildPostItem(
                          "게시물 제목 3", "작성자: 홍길동", "24.10.02", "조회수: 99"),
                      buildPostItem(
                          "게시물 제목 4", "작성자: 홍길동", "24.10.03", "조회수: 99"),
                      buildPostItem(
                          "게시물 제목 5", "작성자: 홍길동", "24.10.05", "조회수: 99"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 게시물 아이템 빌드 함수
  Widget buildPostItem(String title, String author, String date, String views) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(author),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date),
                Text(views),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
