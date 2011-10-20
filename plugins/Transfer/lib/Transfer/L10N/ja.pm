package Transfer::L10N::ja;

use strict;
use base 'Transfer::L10N';
use vars qw( %Lexicon );

our %Lexicon = (
    'Converts Entries to Pages.' => 'ブログ記事をウェブページに変更します',
    'Convert blog template modules and widgets to global templates' => 'ブログのテンプレートモジュールをグローバルテンプレートに変更します',
    'Move or Duplicate the entries and pages between blogs' => 'ブログ記事やウェブページをブログ間で複製したり移動します',
    'Convert to Pages' => 'ウェブページに変更する',
    'Convert to Entries' => 'ブログ記事に変更する',
    'Convert To Global' => 'グローバルテンプレートに変更する',
    'Convert To Blog' => 'ブログテンプレートに変更する',
    'You must specify a blog_id to convert the template to a blog template' => 'テンプレートの変更先のブログIDを入力してください',
#
    'Action will apply these items below' => '以下のアイテムに適用されます',
    'Select the target blog' => '複製または移動先のブログを選択',
    'Actions' => 'アクション',
    'Duplicate Entries' => 'ブログ記事を複製する',
    'Input BlogID of Entries copy to.' => 'ブログ記事の複製先ブログIDを入力してください',
    'Move Entries' => 'ブログ記事を移動する',
    'Input BlogID of Entries move for.' => 'ブログ記事の移動先ブログIDを入力してください',
    'Duplicate Pages' => 'ウェブページを複製する',
    'Input BlogID of Pages copy to.' => 'ウェブページの複製先ブログIDを入力してください',
    'Move Pages' => 'ウェブページを移動する',
    'Input BlogID of Pages move for.' => 'ウェブページの移動先ブログIDを入力してください',
    'Duplicate' => '複製',
    'Move' => '移動',
    'Cancel' => 'キャンセル',
    'Convert to Index Template' => 'インデックステンプレートに変換',
    'Duplicate Assets' => 'アイテムを複製する',
    'Input BlogID of assets copy to.' => 'アイテムの複製先ブログIDを入力してください',
    'Move Assets to Another Blog' => 'アイテムを別ブログに移動する',
    'Input BlogID of assets move for.' => 'アイテムの移動先ブログIDを入力してください',
    'Convert to Asset' => 'アイテムに登録する',
);

1;
