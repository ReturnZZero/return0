import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();

  final List<_CategoryItem> _categories = const [
    _CategoryItem(label: '숙박', assetPath: 'assets/icon_house.png'),
    _CategoryItem(label: '추천코스', assetPath: 'assets/icon_transport.png'),
    _CategoryItem(label: '행사', assetPath: 'assets/icon_walk.png'),
    _CategoryItem(label: '체험관광', assetPath: 'assets/icon_cafe.png'),
    _CategoryItem(label: '음식', assetPath: 'assets/icon_food.png'),
    _CategoryItem(label: '역사관광', assetPath: 'assets/icon_cafe.png'),
    _CategoryItem(label: '스포츠', assetPath: 'assets/icon_walk.png'),
    _CategoryItem(label: '자연관광', assetPath: 'assets/icon_cafe.png'),
    _CategoryItem(label: '쇼핑', assetPath: 'assets/icon_tour.png'),
    _CategoryItem(label: '문화관광', assetPath: 'assets/icon_cafe.png'),
  ];

  int? _selectedIndex;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFFFDE59);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Center(child: Image.asset('assets/icon_login.png', width: 240)),
              const SizedBox(height: 24),
              const Text(
                '반가워요.',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                '오늘은 누구와 어디로 떠나볼까요?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              _buildCategoryGrid(accentColor),
              const SizedBox(height: 24),
              _buildSearchBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(Color accentColor) {
    final double itemWidth =
        (MediaQuery.of(context).size.width - 16 * 2 - 12 * 3) / 4;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(_categories.length, (index) {
        final item = _categories[index];
        final isSelected = _selectedIndex == index;
        return SizedBox(
          width: itemWidth,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              _selectedIndex = _selectedIndex == index ? null : index;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6E6E6)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CategoryIcon(item: item),
                  const SizedBox(height: 8),
                  Text(item.label, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '어디로 떠나고 싶으신가요?',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFDE59),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {},
            child: const Text('검색'),
          ),
        ),
      ],
    );
  }
}

class _CategoryItem {
  const _CategoryItem({required this.label, required this.assetPath});

  final String label;
  final String assetPath;
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.item});

  final _CategoryItem item;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      item.assetPath,
      width: 28,
      height: 28,
      fit: BoxFit.contain,
    );
  }
}
