/// A curated list of profound and authentic Hadiths to rotate daily.
abstract final class Hadiths {
  static const List<({String text, String attribution})> _list = [
    (
      text: "The most beloved of deeds to Allah are those that are most consistent, even if it is small.",
      attribution: "Sahih al-Bukhari 6464"
    ),
    (
      text: "Allah does not look at your forms and possessions but he looks at your hearts and your deeds.",
      attribution: "Sahih Muslim 2564"
    ),
    (
      text: "Richness does not lie in the abundance of (worldly) goods but richness is the richness of the soul (heart, self).",
      attribution: "Sahih al-Bukhari 6446"
    ),
    (
      text: "He who does not show mercy to the people, Allah will not show mercy to him.",
      attribution: "Sahih al-Bukhari 7376"
    ),
    (
      text: "A believer is not bitten from the same hole twice.",
      attribution: "Sahih al-Bukhari 6133"
    ),
    (
      text: "Strange are the ways of a believer for there is good in every affair of his and this is not the case with anyone else except in the case of a believer for if he has an occasion to feel delight, he thanks (God), thus there is a good for him in it, and if he gets into trouble and shows resignation (and endures it patiently), there is a good for him in it.",
      attribution: "Sahih Muslim 2999"
    ),
    (
      text: "None of you will have faith till he wishes for his (Muslim) brother what he likes for himself.",
      attribution: "Sahih al-Bukhari 13"
    ),
    (
      text: "The strong man is not the good wrestler; the strong man is only the one who controls himself when he is angry.",
      attribution: "Sahih al-Bukhari 6114"
    ),
    (
      text: "Every act of goodness is charity.",
      attribution: "Sahih Muslim 1005"
    ),
    (
      text: "Be mindful of Allah, you will find Him before you. Get to know Allah in prosperity and He will know you in adversity. Know that what has passed you by was not going to befall you; and that what has befallen you was not going to pass you by. And know that victory comes with patience, relief with affliction, and ease with hardship.",
      attribution: "40 Hadith Nawawi 19"
    ),
    (
      text: "Two blessings which many people squander: Good health and free time.",
      attribution: "Sahih al-Bukhari 6412"
    ),
    (
      text: "A good word is charity.",
      attribution: "Sahih al-Bukhari 2989"
    ),
    (
      text: "Whoever would like his provision to be increased and his lifespan to be extended, let him maintain the ties of kinship.",
      attribution: "Sahih al-Bukhari 5986"
    ),
    (
      text: "Let whoever believes in Allah and the Last Day either speak good or remain silent.",
      attribution: "Sahih al-Bukhari 6018"
    )
  ];

  /// Returns today's hadith (rotates daily based on day of the year).
  static ({String text, String attribution}) today() {
    final now = DateTime.now();
    final dayOfYear = int.parse(now.difference(DateTime(now.year, 1, 1)).inDays.toString());
    return _list[dayOfYear % _list.length];
  }
}
