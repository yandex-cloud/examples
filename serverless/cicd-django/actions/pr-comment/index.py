import os

from github import Github


def main():
    comment_tag = os.environ['COMMENT_TAG']
    comment_text = os.environ['COMMENT_TEXT']
    g = Github(os.environ['GITHUB_TOKEN'])
    repo = g.get_repo(os.environ['REPO_NAME'])
    pr = repo.get_pull(int(os.environ['PR_NUMBER']))
    comment_prefix = '<!--' + comment_tag + '-->\n'
    comment_with_prefix = comment_prefix + comment_text
    for comment in pr.get_issue_comments():
        text = comment.body
        if text.startswith(comment_prefix):
            comment.edit(comment_with_prefix)
            return
    pr.create_issue_comment(comment_with_prefix)


if __name__ == '__main__':
    main()
